<#
    LiteWin 설정 앱에서 고른 내용을 실제로 적용한다.
    보통은 LiteWin 설정 창 안에서(별도 콘솔 없이) 진행 막대와 함께 실행된다. 콘솔에서 직접 실행해도 된다.
    직접 실행 예:
        powershell -ExecutionPolicy Bypass -File Apply-LiteWin.ps1 -ChoicesFile choices.json
    choices.json:
        { "Mode":"MacInput", "UiOptions":[], "Keys":{"CapsLockToHangul":true}, "NaturalMouseWheel":true,
          "Apps":["steam","mpc-be"], "RemoveEdge":true, "EdgeRedirect":true, "FirstRun":false }
#>
param([Parameter(Mandatory)][string]$ChoicesFile)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib\LiteWin.Modes.ps1')
. (Join-Path $root 'lib\LiteWin.Edge.ps1')
. (Join-Path $root 'lib\LiteWin.Browsers.ps1')

$console = $Host.Name -eq 'ConsoleHost'
if ($console) { try { $Host.UI.RawUI.WindowTitle = 'LiteWin 적용 중...' } catch { } }
if (-not (Test-LWAdmin)) { Write-LWLog '관리자 권한이 필요합니다.' ERROR; if ($console) { Read-Host '종료하려면 Enter' }; return @('관리자 권한') }

$c = Get-Content $ChoicesFile -Raw -Encoding UTF8 | ConvertFrom-Json
$keys = @{}
if ($c.Keys) { foreach ($p in $c.Keys.PSObject.Properties) { $keys[$p.Name] = [bool]$p.Value } }
$shell = @{}
if ($c.Shell) { foreach ($p in $c.Shell.PSObject.Properties) { $shell[$p.Name] = $p.Value } }
$apps = @($c.Apps | Where-Object { $_ })
$failed = @()

Set-LWProgress 2 '준비 중…'

# ---- 1. 인터넷 / winget 이 필요한 작업인지 ----
$needNet = $apps.Count -gt 0 -or $c.Mode -ne 'Lite' -or (-not (Test-WebView2Installed))
if ($needNet -and -not (Test-Internet -WaitSeconds 45)) {
    # 확인이 틀릴 수도 있으므로 설치는 그대로 시도한다 (실패하면 항목별로 알려줌)
    Write-LWLog '인터넷 연결을 확인하지 못했습니다 — 그래도 설치를 시도합니다.' WARN
}

Set-LWProgress 8 '필수 구성요소 확인'
# ---- 2. WebView2 확인 (Edge 를 지워도 꼭 필요) ----
if (-not (Test-WebView2Installed)) {
    Write-LWLog 'WebView2 런타임 설치'
    if (-not (Invoke-Winget -Id 'Microsoft.EdgeWebView2Runtime' -Scope machine)) { $failed += 'WebView2 런타임' }
}

Set-LWProgress 15 '브라우저 설치'
# ---- 2-1. 브라우저: 고른 것 설치 → 기본 지정 → 뺀 것 제거 (마지막 브라우저는 남김) ----
$br = $c.Browsers
foreach ($id in @($br.Install)) { if ($id -and -not (Install-LWBrowser $id)) { $failed += "$($script:LWBrowsers[$id].Name) 설치" } }
if ($c.RemoveEdge -and -not (Get-LWInstalledBrowsers | Where-Object { $_ -ne 'edge' })) {
    # 어떤 이유로든 브라우저가 하나도 없으면 Chrome 을 다시 설치
    Write-LWLog '브라우저가 없어 Chrome 을 설치합니다' WARN
    if (-not (Install-LWBrowser 'chrome')) { $failed += 'Chrome' }
}

# ---- 2-2. ExplorerPatcher 자가 복구: 클래식(Win10) 작업표시줄을 골랐는데 설치되어 있지 않으면 보관본으로 설치 ----
if ($c.Mode -ne 'MacUI' -and "$($shell.ClassicEngine)" -ne 'retrobar' -and -not (Test-Path "$env:ProgramFiles\ExplorerPatcher\ExplorerPatcher.amd64.dll")) {
    $epSetup = Join-Path $script:LWRoot 'payload\ep_setup.exe'
    if (Test-Path $epSetup) {
        Set-LWProgress 30 'Windows 10 작업표시줄(ExplorerPatcher) 설치'
        . (Join-Path $root 'lib\LiteWin.Components.ps1')
        [void](Install-EP -Setup $epSetup)
        if (Test-Path "$env:ProgramFiles\ExplorerPatcher\ExplorerPatcher.amd64.dll") { Write-LWLog 'ExplorerPatcher 설치됨' }
        else {
            $blocked = Test-EPBlockedByDefender
            Write-LWLog ("ExplorerPatcher 설치 실패" + $(if ($blocked) { ' — Windows 보안이 차단했습니다 (설정 > Windows 보안 > 보호 기록)' } else { '' }) + '. 그동안 RetroBar 를 씁니다') WARN
            $failed += 'ExplorerPatcher'
        }
    }
}

# ---- 3. 앱 설치 ----
Set-LWProgress 35 '추가 프로그램 설치'
$failed += Install-LWApps -Ids $apps

Set-LWProgress 70 '모드와 화면 스타일 적용'
# ---- 4. 모드 ----
try {
    Set-LWMode -Mode $c.Mode -UiOptions @($c.UiOptions) -NaturalMouseWheel ([bool]$c.NaturalMouseWheel) -Keys $keys -Shell $shell
} catch {
    Write-LWLog "모드 전환 실패: $_" ERROR
    $failed += "모드 전환 ($($c.Mode))"
}

Set-LWProgress 85 '브라우저 정리'
# ---- 5. Edge (PC 전체 설정) ----
$machineFile = Join-Path $script:LWRoot 'machine.json'
if ($null -ne $c.RemoveEdge) {
    if ($c.RemoveEdge -and -not (Get-LWInstalledBrowsers | Where-Object { $_ -ne 'edge' })) {
        Write-LWLog '다른 브라우저가 없어 Edge 를 지우지 않습니다' WARN
        $c.RemoveEdge = $false
    }
    if ($c.RemoveEdge) {
        if (Test-EdgeInstalled) { [void](Remove-EdgeBrowser) }
        Register-EdgeGuardTask
    } else {
        Unregister-EdgeGuardTask
        if (-not (Test-EdgeInstalled)) {
            Write-LWLog 'Edge 다시 설치'
            Remove-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate' -Name "Install$script:EdgeStableGuid" -ErrorAction SilentlyContinue
            Unregister-EdgeRedirect
            if (-not (Invoke-Winget -Id 'Microsoft.Edge' -Scope machine)) { $failed += 'Edge 재설치' }
        }
    }
    if ($c.RemoveEdge -and $c.EdgeRedirect) { Register-EdgeRedirect }
    elseif ($c.RemoveEdge) { Unregister-EdgeRedirect }
    $mc = if (Test-Path $machineFile) { Get-Content $machineFile -Raw -Encoding UTF8 | ConvertFrom-Json } else { [pscustomobject]@{} }
    $mc | Add-Member -NotePropertyName RemoveEdge -NotePropertyValue ([bool]$c.RemoveEdge) -Force
    $mc | Add-Member -NotePropertyName EdgeRedirect -NotePropertyValue ([bool]$c.EdgeRedirect) -Force
    $mc | ConvertTo-Json | Set-Content $machineFile -Encoding UTF8
}

# ---- 5-1. 기본 브라우저 / 제거 (Edge 처리 뒤에 해야 '마지막 브라우저' 판단이 맞음) ----
if ($br -and $br.Default -and $br.Default -ne (Get-LWDefaultBrowserId)) {
    if (Test-LWBrowserInstalled $br.Default) { [void](Set-LWDefaultBrowser $br.Default) }
}
foreach ($id in @($br.Remove)) {
    if ($id -and $id -ne $br.Default -and -not (Uninstall-LWBrowser $id)) { $failed += "$($script:LWBrowsers[$id].Name) 제거" }
}

# ---- 6. 상태 저장 ----
$state = Get-LWState
$state | Add-Member -NotePropertyName FirstRunDone -NotePropertyValue $true -Force
$state | Add-Member -NotePropertyName LastApps -NotePropertyValue $apps -Force
Set-LWState $state

Set-LWProgress 100 $(if ($failed.Count) { '완료 (일부 실패)' } else { '완료' })
if ($failed.Count) { Write-LWLog ("완료 — 실패 항목: " + ($failed -join ', ') + " (로그: $script:LWLogDir)") WARN }
else { Write-LWLog '모두 완료되었습니다. 마우스/트랙패드 등 일부 설정은 재부팅(또는 로그아웃) 후 완전히 반영됩니다.' }
Remove-Item $ChoicesFile -Force -ErrorAction SilentlyContinue
if ($console -and -not $c.FirstRun) { Read-Host "`n닫으려면 Enter" }
return , @($failed)
