<#
    LiteWin 설정 앱에서 고른 내용을 실제로 적용한다 (관리자 콘솔 창에서 진행 상황 표시).
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

$Host.UI.RawUI.WindowTitle = 'LiteWin 적용 중...'
if (-not (Test-LWAdmin)) { Write-LWLog '관리자 권한이 필요합니다.' ERROR; Read-Host '종료하려면 Enter'; exit 1 }

$c = Get-Content $ChoicesFile -Raw -Encoding UTF8 | ConvertFrom-Json
$keys = @{}
if ($c.Keys) { foreach ($p in $c.Keys.PSObject.Properties) { $keys[$p.Name] = [bool]$p.Value } }
$shell = @{}
if ($c.Shell) { foreach ($p in $c.Shell.PSObject.Properties) { $shell[$p.Name] = $p.Value } }
$apps = @($c.Apps | Where-Object { $_ })
$failed = @()

Write-Host "`n=== LiteWin 적용 ===" -ForegroundColor Cyan

# ---- 1. 인터넷 / winget 이 필요한 작업인지 ----
$needNet = $apps.Count -gt 0 -or $c.Mode -ne 'Lite' -or (-not (Test-WebView2Installed))
if ($needNet -and -not (Test-Internet -WaitSeconds 45)) {
    # 확인이 틀릴 수도 있으므로 설치는 그대로 시도한다 (실패하면 항목별로 알려줌)
    Write-LWLog '인터넷 연결을 확인하지 못했습니다 — 그래도 설치를 시도합니다.' WARN
}

# ---- 2. WebView2 확인 (Edge 를 지워도 꼭 필요) ----
if (-not (Test-WebView2Installed)) {
    Write-LWLog 'WebView2 런타임 설치'
    if (-not (Invoke-Winget -Id 'Microsoft.EdgeWebView2Runtime' -Scope machine)) { $failed += 'WebView2 런타임' }
}

# ---- 2-1. 브라우저 확인 (설치 중 Chrome 설치가 실패했으면 다시) ----
if (-not (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe")) {
    Write-LWLog 'Chrome 이 없어 다시 설치합니다'
    if (-not (Invoke-Winget -Id 'Google.Chrome' -Scope machine)) { $failed += 'Chrome' }
}

# ---- 3. 앱 설치 ----
$failed += Install-LWApps -Ids $apps

# ---- 4. 모드 ----
try {
    Set-LWMode -Mode $c.Mode -UiOptions @($c.UiOptions) -NaturalMouseWheel ([bool]$c.NaturalMouseWheel) -Keys $keys -Shell $shell
} catch {
    Write-LWLog "모드 전환 실패: $_" ERROR
    $failed += "모드 전환 ($($c.Mode))"
}

# ---- 5. Edge (PC 전체 설정) ----
$machineFile = Join-Path $script:LWRoot 'machine.json'
if ($null -ne $c.RemoveEdge) {
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
    @{ RemoveEdge = [bool]$c.RemoveEdge; EdgeRedirect = [bool]$c.EdgeRedirect } |
        ConvertTo-Json | Set-Content $machineFile -Encoding UTF8
}

# ---- 6. 상태 저장 ----
$state = Get-LWState
$state | Add-Member -NotePropertyName FirstRunDone -NotePropertyValue $true -Force
$state | Add-Member -NotePropertyName LastApps -NotePropertyValue $apps -Force
Set-LWState $state

Write-Host ''
if ($failed.Count) {
    Write-LWLog ("완료 — 실패 항목: " + ($failed -join ', ')) WARN
    Write-Host "로그: $script:LWLogDir" -ForegroundColor Yellow
} else {
    Write-LWLog '모두 완료되었습니다.'
}
Write-Host '마우스/트랙패드 등 일부 설정은 재부팅(또는 로그아웃) 후 완전히 반영됩니다.' -ForegroundColor Cyan
Remove-Item $ChoicesFile -Force -ErrorAction SilentlyContinue
Read-Host "`n닫으려면 Enter"
