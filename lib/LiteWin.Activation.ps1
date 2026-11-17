<#
    Windows 정품 인증 진단·복구 (우회 아님 — 본인 Pro 라이선스로 정상 인증되도록 막힌 곳을 찾아 고친다)

    "정품 인증 서버에 연결할 수 없습니다"의 흔한 원인
      1) 시계가 어긋남        → TLS 인증서 검사 실패 (0x80072F8F). VM 에서 특히 흔함 → 시간 동기화
      2) 인증 서버로 못 나감   → DNS/방화벽/프록시 (0x80072EE7, 0x80072EFD) → 서버별 연결 확인
      3) 관련 서비스가 꺼짐    → sppsvc, ClipSVC, LicenseManager, wlidsvc
      4) 라이선스가 이 기기에 없음 → VM 은 PC 와 하드웨어가 달라 PC 의 디지털 라이선스가 적용되지 않는다.
                                    제품 키를 직접 넣어야 한다 (0x803F7001)
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:WindowsAppId = '55c92734-d682-4d71-983e-d6ec3f16059f'
$script:ActivationHosts = @('activation-v2.sls.microsoft.com', 'validation-v2.sls.microsoft.com', 'displaycatalog.mp.microsoft.com',
                            'licensing.mp.microsoft.com', 'login.live.com', 'go.microsoft.com')
$script:ActivationErrors = @{
    '80072F8F' = 'PC 시간이 맞지 않아 보안 연결(TLS)이 실패했습니다 → 시간 동기화'
    '80072EE7' = '서버 이름을 찾지 못했습니다 (DNS/인터넷 연결)'
    '80072EFD' = '서버에 연결하지 못했습니다 (방화벽/프록시/네트워크)'
    '80072EE2' = '서버 응답 시간 초과 (네트워크)'
    '803F7001' = '이 기기에 맞는 라이선스가 없습니다 → 제품 키를 입력하세요 (VM 은 PC 의 디지털 라이선스를 쓰지 못함)'
    'C004F074' = 'KMS(회사용 인증 서버)를 찾지 못했습니다 → 볼륨 키가 들어가 있음. 본인 Pro 제품 키를 입력하세요'
    'C004F050' = '제품 키가 올바르지 않습니다'
    'C004C003' = '이 제품 키는 차단되었거나 쓸 수 없습니다'
    'C004C008' = '이 제품 키는 허용된 기기 수를 넘었습니다 (다른 PC 에서 쓰는 중)'
    'C004F012' = '라이선스 저장소 문제 → 서비스 재시작 후 다시 시도'
    '8007232B' = 'KMS 서버 DNS 이름을 찾지 못했습니다 → 소매/OEM 제품 키를 입력하세요'
}

function Get-LWActivationStatus {
    $p = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId='$script:WindowsAppId' AND PartialProductKey IS NOT NULL" -ErrorAction SilentlyContinue |
         Select-Object -First 1
    if (-not $p) { return [pscustomobject]@{ Activated = $false; Text = '제품 키 없음'; Channel = ''; Key = '' } }
    $names = @{ 0 = '라이선스 없음'; 1 = '정품 인증됨'; 2 = '유예 기간'; 3 = '유예 기간(추가)'; 4 = '정품이 아님(유예 만료)'; 5 = '알림 모드(미인증)'; 6 = '연장 유예' }
    [pscustomobject]@{
        Activated = ($p.LicenseStatus -eq 1)
        Text      = $names[[int]$p.LicenseStatus]
        Channel   = "$($p.ProductKeyChannel)"
        Key       = "*****-$($p.PartialProductKey)"
        Product   = $p.Name
    }
}

function Get-ActivationErrorText($err) {
    $hex = $null
    if ($err -is [System.Management.Automation.ErrorRecord]) { $err = $err.Exception }
    if ($err -and $err.PSObject.Properties['HResult']) { $hex = '{0:X8}' -f ($err.HResult -band 0xFFFFFFFF) }
    $m = [regex]::Match("$err", '0x([0-9A-Fa-f]{8})')
    if ($m.Success) { $hex = $m.Groups[1].Value.ToUpper() }
    if ($hex -and $script:ActivationErrors.ContainsKey($hex)) { return "0x$hex — $($script:ActivationErrors[$hex])" }
    if ($hex) { return "0x$hex — $err" }
    return "$err"
}

function Test-LWClock {
    <# 인터넷 시간(HTTP Date 헤더)과 비교해 몇 분 차이 나는지 #>
    foreach ($u in 'https://www.microsoft.com/', 'https://www.google.com/') {
        try {
            $r = Invoke-WebRequest -UseBasicParsing -Uri $u -Method Head -TimeoutSec 10 -ErrorAction Stop
            $remote = [DateTime]::Parse($r.Headers['Date']).ToUniversalTime()
            return [Math]::Round(([DateTime]::UtcNow - $remote).TotalMinutes, 1)
        } catch {
            # 시계가 크게 어긋나면 https 자체가 실패할 수 있다 → http 로 다시
            try {
                $r = Invoke-WebRequest -UseBasicParsing -Uri ($u -replace '^https', 'http') -Method Head -TimeoutSec 10 -MaximumRedirection 0 -ErrorAction SilentlyContinue
                if ($r -and $r.Headers['Date']) { return [Math]::Round(([DateTime]::UtcNow - [DateTime]::Parse($r.Headers['Date']).ToUniversalTime()).TotalMinutes, 1) }
            } catch { }
        }
    }
    return $null
}

function Invoke-LWActivationRepair {
    <#
        .SYNOPSIS 진단하고 고칠 수 있는 것은 고친다. 결과를 줄 단위 문자열로 돌려준다.
    #>
    $out = New-Object System.Collections.Generic.List[string]
    $st = Get-LWActivationStatus
    $out.Add("현재 상태: $($st.Text)  (키 $($st.Key), 채널 $($st.Channel))")

    # 1) 서비스
    foreach ($svc in 'sppsvc', 'ClipSVC', 'LicenseManager', 'wlidsvc', 'W32Time') {
        $s = Get-Service $svc -ErrorAction SilentlyContinue
        if (-not $s) { $out.Add("서비스 ${svc}: 없음"); continue }
        if ($s.StartType -eq 'Disabled') {
            try { Set-Service $svc -StartupType Manual; $out.Add("서비스 ${svc}: 꺼져 있어서 '수동'으로 되돌림") } catch { $out.Add("서비스 ${svc}: 꺼져 있음 (되돌리기 실패)") }
        }
    }

    # 2) 시계
    try {
        Set-Service W32Time -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service W32Time -ErrorAction SilentlyContinue
        $skew = Test-LWClock
        if ($null -eq $skew) { $out.Add('시간: 인터넷 시간과 비교하지 못함 (인터넷 연결 확인 필요)') }
        elseif ([Math]::Abs($skew) -gt 3) {
            [void](Invoke-Hidden -File "$env:WINDIR\System32\w32tm.exe" -ArgumentList @('/config', '/manualpeerlist:time.windows.com,0x9', '/syncfromflags:manual', '/update'))
            [void](Invoke-Hidden -File "$env:WINDIR\System32\w32tm.exe" -ArgumentList @('/resync', '/force'))
            $after = Test-LWClock
            $out.Add("시간: $skew 분 어긋나 있어서 동기화 → 지금 $after 분 차이")
            if ($null -ne $after -and [Math]::Abs($after) -gt 3) { $out.Add('  ! 동기화가 안 됩니다. VMware 의 VM 설정 > 옵션 > VMware Tools > "게스트 시간을 호스트와 동기화"를 켜세요') }
        } else { $out.Add("시간: 정상 ($skew 분 차이)") }
    } catch { $out.Add("시간 확인 실패: $_") }

    # 3) 인증 서버 연결
    $bad = @()
    foreach ($h in $script:ActivationHosts) {
        try { $ok = Test-NetConnection -ComputerName $h -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue } catch { $ok = $false }
        if (-not $ok) { $bad += $h }
    }
    if ($bad.Count) { $out.Add("인증 서버 연결 실패: $($bad -join ', ') — VM 네트워크(NAT/브리지), 방화벽, 프록시를 확인하세요") }
    else { $out.Add('인증 서버 연결: 정상') }
    $proxy = (Invoke-Hidden -File "$env:WINDIR\System32\netsh.exe" -ArgumentList @('winhttp', 'show', 'proxy')).Output
    if ($proxy -match '(Proxy Server|프록시 서버)\(s\)?\s*:\s*(\S+)') { $out.Add("WinHTTP 프록시 설정 있음: $($Matches[2]) — 인증이 막히면 'netsh winhttp reset proxy'") }

    # 4) 인증 시도
    $r = Invoke-LWActivate
    $out.Add($r)
    if (-not (Get-LWActivationStatus).Activated -and $st.Channel -match 'Retail' -and $st.Key -match '3V66T$') {
        $out.Add('  → 지금은 설치용 일반 키(…3V66T)라 이 VM 에 라이선스가 없습니다. [제품 키 입력] 으로 본인 Pro 키를 넣으세요.')
    }
    return $out
}

function Invoke-LWActivate {
    try {
        $p = Get-CimInstance SoftwareLicensingProduct -Filter "ApplicationId='$script:WindowsAppId' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
        if (-not $p) { return '인증 시도: 제품 키가 없습니다' }
        Invoke-CimMethod -InputObject $p -MethodName Activate -ErrorAction Stop | Out-Null
        $svc = Get-CimInstance SoftwareLicensingService; Invoke-CimMethod -InputObject $svc -MethodName RefreshLicenseStatus | Out-Null
        $st = Get-LWActivationStatus
        return "인증 시도: $($st.Text)"
    } catch { return "인증 시도 실패: $(Get-ActivationErrorText $_)" }
}

function Set-LWProductKey([string]$Key) {
    $Key = $Key.Trim().ToUpper()
    if ($Key -notmatch '^[A-Z0-9]{5}(-[A-Z0-9]{5}){4}$') { return '제품 키 형식이 아닙니다 (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)' }
    try {
        $svc = Get-CimInstance SoftwareLicensingService
        Invoke-CimMethod -InputObject $svc -MethodName InstallProductKey -Arguments @{ ProductKey = $Key } -ErrorAction Stop | Out-Null
        Invoke-CimMethod -InputObject $svc -MethodName RefreshLicenseStatus | Out-Null
        Write-LWLog '제품 키 입력됨 (끝 5자리만 기록)';
        return "제품 키 입력됨. $(Invoke-LWActivate)"
    } catch { return "제품 키 입력 실패: $(Get-ActivationErrorText $_)" }
}
