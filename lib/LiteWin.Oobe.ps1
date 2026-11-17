<#
    Windows 설치 화면(OOBE)의 제조사 등록 페이지 — 'Administrator 로 사용' 체크박스.
    순서: Windows 로컬 계정 화면(이름·암호) → LiteWin 등록 페이지(이 체크박스) → 첫 로그인
    OOBE 는 계정 화면 앞에 제조사 페이지를 넣을 수 없어서(문서상 OEM 등록 페이지는 OOBE 의 마지막),
    체크 결과는 첫 로그인 때 LiteWin 이 읽어서 처리한다.

    등록 페이지가 표시되려면 Oobe.xml(제목·부제·customerinfo·체크박스 1개 이상)과 공개 키(Pubkey.blob)가
    Windows\System32\Oobe\Info 에 있어야 한다. LiteWin 은 등록 정보를 어디에도 보내지 않으므로
    빌드할 때 만든 개인 키는 바로 버리고, 첫 로그인 때 암호화된 정보 파일도 지운다.
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:OobeAdminLabel = '기본 제공 Administrator 계정으로 사용 (권장하지 않음, 로그인 후 경고를 두 번 확인)'

function New-LWOobeRegistration {
    <# 빌드용: 마운트한 이미지의 Windows\System32\Oobe\Info 에 Oobe.xml 과 Pubkey.blob 을 만든다 #>
    param([Parameter(Mandatory)][string]$InfoDir)
    New-Item -ItemType Directory -Path $InfoDir -Force | Out-Null
    $esc = { param($t) [Security.SecurityElement]::Escape($t) }
    $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<FirstExperience>
  <oobe>
    <oem>
      <name>LiteWin</name>
      <registration>
        <title>$(& $esc 'LiteWin 계정 옵션')</title>
        <subtitle>$(& $esc '보통은 아무것도 체크하지 않고 [다음] 을 누르세요. 여기 입력한 내용은 이 PC 밖으로 보내지 않습니다.')</subtitle>
        <customerinfo>
          <label>$(& $esc '등록 정보 저장 (LiteWin 은 쓰지 않으니 체크하지 않아도 됩니다)')</label>
          <defaultvalue>false</defaultvalue>
        </customerinfo>
        <checkbox1>
          <label>$(& $esc $script:OobeAdminLabel)</label>
          <defaultvalue>false</defaultvalue>
        </checkbox1>
        <hideSkip>true</hideSkip>
      </registration>
    </oem>
  </oobe>
</FirstExperience>
"@
    [void][xml]$xml   # 문법 검사
    [IO.File]::WriteAllText((Join-Path $InfoDir 'Oobe.xml'), $xml, (New-Object Text.UTF8Encoding $true))
    # 공개 키: CryptoAPI PUBLICKEYBLOB (RSA 키 교환, CALG_RSA_KEYX) — 문서의 CryptExportKey(PUBLICKEYBLOB) 와 같은 형식
    $rsa = New-Object Security.Cryptography.RSACryptoServiceProvider 2048
    try { [IO.File]::WriteAllBytes((Join-Path $InfoDir 'Pubkey.blob'), $rsa.ExportCspBlob($false)) }
    finally { $rsa.PersistKeyInCsp = $false; $rsa.Dispose() }   # 개인 키는 저장하지 않는다
}

function Get-LWOobeAdminChoice {
    <#
        첫 로그인: 등록 페이지에서 Administrator 를 체크했는지. $true / $false / $null(페이지가 안 나왔거나 알 수 없음)
        결과는 ProgramData\LiteWin\oobe-choice.json 에 남기고, 등록 정보 파일은 지운다.
    #>
    $cache = Join-Path $script:LWRoot 'oobe-choice.json'
    if (Test-Path $cache) {
        try { $c = Get-Content $cache -Raw -Encoding UTF8 | ConvertFrom-Json; return $c.UseAdministrator } catch { }
    }
    $info = Join-Path $env:WINDIR 'System32\oobe\info'
    $file = Join-Path $info 'Userchoices.xml'
    $result = $null
    if (Test-Path $file) {
        $raw = Get-Content $file -Raw -ErrorAction SilentlyContinue
        Write-LWLog "OOBE 등록 페이지 결과 파일:`n$raw" -File 'FirstLogon.log'
        $result = ConvertFrom-LWUserChoices $raw
    } else {
        Write-LWLog 'OOBE 등록 페이지 결과 없음 (페이지가 표시되지 않았음) — LiteWin 마법사에서 묻습니다' -File 'FirstLogon.log'
    }
    # 등록 정보(암호화된 이름·이메일 등)는 쓰지 않으므로 지운다
    foreach ($f in 'Userdata.blob', 'SessionKey.blob', 'Userchoices.xml') { Remove-Item (Join-Path $info $f) -Force -ErrorAction SilentlyContinue }
    @{ UseAdministrator = $result } | ConvertTo-Json | Set-Content $cache -Encoding UTF8
    return $result
}

function ConvertFrom-LWUserChoices([string]$Raw) {
    <#
        Userchoices.xml 에서 Administrator 체크박스 값을 찾는다. 파일 형식이 문서에 나와 있지 않아서
        'Administrator' 가 들어 있는 항목(또는 checkbox1) 주변의 true/false 값을 찾는다. 모르면 $null.
    #>
    if (-not $Raw) { return $null }
    try { $doc = [xml]$Raw } catch { return $null }
    $isTrue  = '^(true|1|yes|checked|on)$'
    $isFalse = '^(false|0|no|unchecked|off)$'
    $hits = @()
    foreach ($n in $doc.SelectNodes('//*')) {
        $own = @($n.Attributes | ForEach-Object { $_.Value }) + @($n.ChildNodes | Where-Object { $_.NodeType -eq 'Text' } | ForEach-Object { $_.Value })
        if (($own -join ' ') -match 'Administrator' -or $n.LocalName -match '^checkbox1$') { $hits += $n }
    }
    foreach ($h in $hits) {
        foreach ($scope in @($h, $h.ParentNode)) {
            if (-not $scope -or $scope -is [xml]) { continue }
            $vals = @($scope.Attributes | ForEach-Object { $_.Value })
            $vals += @($scope.SelectNodes('.//*') | Where-Object { -not $_.HasChildNodes -or $_.ChildNodes.Count -eq 1 -and $_.FirstChild.NodeType -eq 'Text' } | ForEach-Object { $_.InnerText })
            $vals += @($scope.SelectNodes('.//@*') | ForEach-Object { $_.Value })
            if ($scope.ChildNodes.Count -eq 1 -and $scope.FirstChild.NodeType -eq 'Text') { $vals += $scope.InnerText }
            $vals = @($vals | ForEach-Object { "$_".Trim() } | Where-Object { $_ -and $_ -notmatch 'Administrator' })
            if ($vals | Where-Object { $_ -match $isTrue })  { return $true }
            if ($vals | Where-Object { $_ -match $isFalse }) { return $false }
        }
    }
    return $null
}
