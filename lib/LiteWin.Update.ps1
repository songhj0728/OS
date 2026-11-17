<#
    LiteWin 온라인 업데이트 — ISO 를 다시 만들지 않고 설치된 PC 의 LiteWin 만 최신으로 바꾼다.
    공개 저장소(기본 이 저장소 songhj0728/OS)의 최신 Release 에서 LiteWin-update.zip 을 받아
    GitHub 가 제공하는 SHA-256 으로 검증한 뒤 lib/app/apps/macstyle/bin 을 교체한다.
    바뀌지 않는 것: 설치 이미지 단계(지우는 앱, 레지스트리 정책, Edge 제거, 기본 배경) → 이런 변경은 ISO 재빌드가 필요.
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:UpdateConfigFile = Join-Path $script:LWRoot 'update.json'
$script:VersionFile      = Join-Path $script:LWRoot 'version.json'
$script:DefaultUpdateRepo = 'songhj0728/OS'

function Get-LWUpdateRepo {
    if (Test-Path $script:UpdateConfigFile) {
        try { $c = Get-Content $script:UpdateConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json; if ($c.Repo) { return $c.Repo } } catch { }
    }
    return $script:DefaultUpdateRepo
}

function Get-LWVersion {
    if (Test-Path $script:VersionFile) {
        try { return (Get-Content $script:VersionFile -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { }
    }
    return [pscustomobject]@{ Version = '0.0.0.0'; Commit = ''; Source = '알 수 없음' }
}

function ConvertTo-LWVersion([string]$s) {
    $v = $null
    if ($s -and [version]::TryParse(($s -replace '^v', ''), [ref]$v)) { return $v }
    return [version]'0.0.0.0'
}

function Get-LWLatestRelease {
    $repo = Get-LWUpdateRepo
    $h = @{ 'User-Agent' = 'LiteWin-Updater'; 'Accept' = 'application/vnd.github+json' }
    $r = Invoke-RestMethod -UseBasicParsing -Headers $h -Uri "https://api.github.com/repos/$repo/releases/latest" -TimeoutSec 30
    $a = $r.assets | Where-Object name -eq 'LiteWin-update.zip' | Select-Object -First 1
    if (-not $a) { throw "최신 Release 에 LiteWin-update.zip 이 없습니다 ($repo)" }
    [pscustomobject]@{
        Tag = $r.tag_name; Version = (ConvertTo-LWVersion $r.tag_name); Notes = "$($r.body)"
        Url = $a.browser_download_url; Size = $a.size
        Sha256 = if ($a.digest -match '^sha256:([0-9a-fA-F]{64})$') { $Matches[1].ToUpper() } else { $null }
    }
}

function Test-LWUpdate {
    <# .OUTPUTS @{ Available; Current; Latest; Release } #>
    $cur = Get-LWVersion
    $rel = Get-LWLatestRelease
    [pscustomobject]@{
        Available = $rel.Version -gt (ConvertTo-LWVersion $cur.Version)
        Current = $cur.Version; Latest = $rel.Tag; Release = $rel
    }
}

function Install-LWUpdate {
    <#
        .SYNOPSIS 최신 LiteWin 으로 교체 (관리자). 실행 중인 LiteWin 프로그램은 잠깐 멈췄다가 다시 시작한다.
        .OUTPUTS 결과 문자열
    #>
    param([switch]$Force)
    $chk = Test-LWUpdate
    if (-not $chk.Available -and -not $Force) { return "이미 최신입니다 ($($chk.Current))" }
    $rel = $chk.Release
    if (-not $rel.Sha256) { throw '배포처가 SHA-256 을 제공하지 않아 설치하지 않습니다' }

    $tmp = Join-Path $env:TEMP ('litewin-update-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    try {
        $zip = Join-Path $tmp 'LiteWin-update.zip'
        Invoke-WebRequest -UseBasicParsing -Uri $rel.Url -OutFile $zip -TimeoutSec 300
        $hash = (Get-FileHash $zip -Algorithm SHA256).Hash
        if ($hash -ne $rel.Sha256) { throw "해시 불일치 — 업데이트 파일이 손상되었거나 바뀌었습니다" }
        $x = Join-Path $tmp 'x'
        Expand-Archive $zip $x -Force
        if (-not (Test-Path (Join-Path $x 'lib\LiteWin.Common.ps1'))) { throw '업데이트 파일 구조가 올바르지 않습니다' }

        # 실행 중인 LiteWin 프로그램 멈춤 (exe 교체를 위해) — 설정 창 자신(LiteWinSettings)은 끝난 뒤 다시 연다
        foreach ($n in 'LiteWinCaption', 'LiteWinKeys') { Get-Process $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

        foreach ($d in 'lib', 'app', 'apps', 'macstyle') {
            if (-not (Test-Path (Join-Path $x $d))) { continue }
            $r = Invoke-Hidden -File "$env:WINDIR\System32\robocopy.exe" -ArgumentList @((Join-Path $x $d), (Join-Path $script:LWRoot $d), '/MIR', '/R:1', '/W:1', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
            if ($r.Code -ge 8) { throw "복사 실패: $d (robocopy $($r.Code))" }
        }
        # bin: 실행 중인 LiteWinSettings.exe 는 바로 못 바꾸므로 .new 로 두고 다음 실행 때 교체
        New-Item -ItemType Directory -Path (Join-Path $script:LWRoot 'bin') -Force | Out-Null
        foreach ($f in Get-ChildItem (Join-Path $x 'bin') -File -ErrorAction SilentlyContinue) {
            $dst = Join-Path $script:LWRoot "bin\$($f.Name)"
            try { Copy-Item $f.FullName $dst -Force -ErrorAction Stop }
            catch { Copy-Item $f.FullName "$dst.new" -Force }
        }
        Copy-Item (Join-Path $x 'version.json') $script:VersionFile -Force -ErrorAction SilentlyContinue
        Write-LWLog "LiteWin 업데이트: $($chk.Current) → $($rel.Tag)" -File 'Components.log'
    } finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 새 코드로 셸/작업 다시 적용
    try {
        $ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
        [void](Invoke-Hidden -File $ps -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
            ". '$script:LWRoot\lib\LiteWin.Components.ps1'; Register-LWComponentTask"))
    } catch { }
    Get-ScheduledTask -TaskPath '\LiteWin\' -TaskName 'LiteWin MacKeys*' -ErrorAction SilentlyContinue | Where-Object State -ne 'Disabled' |
        ForEach-Object { Start-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName }
    return "업데이트 완료: $($chk.Current) → $($rel.Tag)"
}

function Complete-LWPendingBinaries {
    <# 지난 업데이트 때 사용 중이라 못 바꾼 exe(.new)를 교체 — LiteWinSettings 가 시작할 때 호출 #>
    foreach ($n in Get-ChildItem (Join-Path $script:LWRoot 'bin') -Filter '*.new' -ErrorAction SilentlyContinue) {
        $dst = $n.FullName -replace '\.new$', ''
        try { Move-Item $n.FullName $dst -Force -ErrorAction Stop } catch { }
    }
}
