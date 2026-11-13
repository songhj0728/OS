<#
    브라우저 설치 / 제거 / 기본 브라우저 지정
    - 설치·제거: winget (공식 저장소, 해시 검증). Edge 는 LiteWin.Edge.ps1 이 따로 처리.
    - 기본 브라우저: Windows 11 은 프로그램이 현재 사용자의 기본 브라우저를 몰래 바꾸지 못하게 막아 두었다.
      그래서 (1) 앞으로 만들 계정용 기본값(OEMDefaultAssociations)을 바꾸고
             (2) 현재 사용자에게는 그 브라우저의 '기본 앱' 설정 화면을 열어 [기본값으로 설정] 한 번만 누르게 한다.
    - 마지막 남은 브라우저는 지우지 않는다 (인터넷에 못 들어가는 상태 방지).
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:LWBrowsers = [ordered]@{
    chrome  = @{ Name = 'Google Chrome';   Winget = 'Google.Chrome';   Reg = 'Google Chrome'
                 Exe = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") }
    edge    = @{ Name = 'Microsoft Edge';  Winget = 'Microsoft.Edge';  Reg = 'Microsoft Edge'
                 Exe = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") }
    brave   = @{ Name = 'Brave';           Winget = 'Brave.Brave';     Reg = 'Brave'
                 Exe = @("$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe", "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\Application\brave.exe") }
    whale   = @{ Name = '네이버 웨일';      Winget = 'Naver.Whale';     Reg = 'Naver Whale'
                 Exe = @("$env:ProgramFiles\Naver\Naver Whale\Application\whale.exe", "${env:ProgramFiles(x86)}\Naver\Naver Whale\Application\whale.exe", "$env:LOCALAPPDATA\Naver\Naver Whale\Application\whale.exe") }
    opera   = @{ Name = 'Opera';           Winget = 'Opera.Opera';     Reg = 'Opera'
                 Exe = @("$env:ProgramFiles\Opera\opera.exe", "$env:LOCALAPPDATA\Programs\Opera\opera.exe", "$env:LOCALAPPDATA\Programs\Opera\launcher.exe") }
    firefox = @{ Name = 'Mozilla Firefox'; Winget = 'Mozilla.Firefox'; Reg = 'Firefox'
                 Exe = @("$env:ProgramFiles\Mozilla Firefox\firefox.exe", "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe") }
}

function Test-LWBrowserInstalled([string]$Id) {
    foreach ($p in $script:LWBrowsers[$Id].Exe) { if ($p -and (Test-Path $p)) { return $true } }
    return $false
}

function Get-LWInstalledBrowsers {
    @($script:LWBrowsers.Keys | Where-Object { Test-LWBrowserInstalled $_ })
}

function Find-BrowserRegistration([string]$Id) {
    <# StartMenuInternet 등록 → @{ Key; ProgId; RegisteredName; Scope } #>
    $b = $script:LWBrowsers[$Id]
    foreach ($root in 'HKLM:\SOFTWARE\Clients\StartMenuInternet', 'HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet', 'HKCU:\Software\Clients\StartMenuInternet') {
        foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
            $display = (Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue).'(default)'
            if ($k.PSChildName -notlike "*$($b.Reg)*" -and "$display" -notlike "*$($b.Reg)*") { continue }
            $https = (Get-ItemProperty (Join-Path $k.PSPath 'Capabilities\URLAssociations') -ErrorAction SilentlyContinue).https
            $regName = $null
            foreach ($ra in 'HKLM:\SOFTWARE\RegisteredApplications', 'HKCU:\Software\RegisteredApplications') {
                $props = Get-ItemProperty $ra -ErrorAction SilentlyContinue
                if (-not $props) { continue }
                foreach ($p in $props.PSObject.Properties) {
                    if ("$($p.Value)" -like "*StartMenuInternet\$($k.PSChildName)\Capabilities*") { $regName = $p.Name }
                }
            }
            return [pscustomobject]@{ ProgId = $https; RegisteredName = $regName; Scope = $(if ($root -like 'HKCU*') { 'User' } else { 'Machine' }) }
        }
    }
    return $null
}

function Install-LWBrowser([string]$Id) {
    if ($Id -eq 'edge') { throw 'Edge 는 Install-EdgeBack 을 사용' }
    if (Test-LWBrowserInstalled $Id) { return $true }
    $b = $script:LWBrowsers[$Id]
    Write-LWLog "브라우저 설치: $($b.Name)"
    $ok = Invoke-Winget -Id $b.Winget -Scope machine
    if (-not $ok) { $ok = Invoke-Winget -Id $b.Winget }   # 일부 브라우저는 사용자 범위 설치만 제공
    return ($ok -and (Test-LWBrowserInstalled $Id))
}

function Uninstall-LWBrowser([string]$Id) {
    $left = @(Get-LWInstalledBrowsers | Where-Object { $_ -ne $Id })
    if ($left.Count -eq 0) { Write-LWLog "마지막 브라우저($Id)는 지우지 않습니다" WARN; return $false }
    $b = $script:LWBrowsers[$Id]
    Write-LWLog "브라우저 제거: $($b.Name)"
    $winget = Wait-Winget -TimeoutSeconds 30
    if ($winget) {
        & $winget uninstall --id $b.Winget --exact --silent --accept-source-agreements --disable-interactivity | Out-Host
    }
    return -not (Test-LWBrowserInstalled $Id)
}

function Set-LWDefaultBrowser([string]$Id, [switch]$NoPrompt) {
    $b = $script:LWBrowsers[$Id]
    $reg = Find-BrowserRegistration $Id
    if (-not $reg -or -not $reg.ProgId) { Write-LWLog "$($b.Name) 의 등록 정보를 찾지 못해 기본 브라우저로 지정하지 못했습니다" WARN; return $false }

    # (1) 앞으로 만들 계정의 기본값
    try {
        . (Join-Path $PSScriptRoot 'LiteWin.Assoc.ps1')
        $xml = Join-Path $script:LWRoot 'DefaultAssociations.xml'
        $src = if (Test-Path $xml) { $xml } else { "$env:WINDIR\System32\OEMDefaultAssociations.xml" }
        $entries = [ordered]@{}
        foreach ($e in $script:BrowserIdentifiers) { $entries[$e] = @($reg.ProgId, $b.Name) }
        Merge-DefaultAssociations -Source $src -Output $xml -Entries $entries
        & dism.exe /Online /English "/Import-DefaultAppAssociations:$xml" | Out-Null
    } catch { Write-LWLog "새 계정 기본 브라우저 지정 실패: $_" WARN }

    # (2) 현재 사용자: Windows 기본 앱 화면을 열어 [기본값으로 설정] 을 누르게 한다
    if (-not $NoPrompt) {
        $uri = if ($reg.RegisteredName) {
            'ms-settings:defaultapps?registered{0}={1}' -f $(if ($reg.Scope -eq 'User') { 'AppUser' } else { 'AppMachine' }), [uri]::EscapeDataString($reg.RegisteredName)
        } else { 'ms-settings:defaultapps' }
        Start-Process $uri
    }
    $m = Join-Path $script:LWRoot 'machine.json'
    $cfg = if (Test-Path $m) { Get-Content $m -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
    $cfg | Add-Member -NotePropertyName BrowserName -NotePropertyValue $b.Name -Force
    $cfg | Add-Member -NotePropertyName DefaultBrowser -NotePropertyValue $Id -Force
    $cfg | ConvertTo-Json | Set-Content $m -Encoding UTF8
    return $true
}

function Get-LWDefaultBrowserId {
    $m = Join-Path $script:LWRoot 'machine.json'
    if (Test-Path $m) {
        $c = Get-Content $m -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($c.DefaultBrowser) { return $c.DefaultBrowser }
    }
    # 현재 사용자 설정에서 추정
    $pid2 = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction SilentlyContinue).ProgId
    switch -Regex ("$pid2") {
        '^Chrome' { return 'chrome' } '^MSEdge' { return 'edge' } '^Brave' { return 'brave' }
        '^Whale' { return 'whale' } '^Opera' { return 'opera' } '^Firefox' { return 'firefox' }
    }
    return 'chrome'
}
