<#
    모드 전환: Lite(라이트 윈도우) / MacInput(맥 입력) / MacUI(맥 입력 + UI)
    현재 로그인한 사용자 기준 (관리자 권한 필요: 예약 작업, 마우스 휠 HKLM, Windhawk 서비스)

    되돌리기 원리: 맥 스타일을 처음 켜기 직전 값을 스냅샷으로 한 번 저장하고,
                  라이트로 돌아갈 때 그 값을 복원한다. (%LOCALAPPDATA%\LiteWin\snapshot-*.json)
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')
. (Join-Path $PSScriptRoot 'LiteWin.Apps.ps1')
. (Join-Path $PSScriptRoot 'LiteWin.Shell.ps1')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'macstyle\MacStyleSettings.ps1')

# UI 옵션 (Windows 내장 — 추가 메모리 0)
$script:BuiltinUiOptions = [ordered]@{
    DarkMode        = '다크 모드'
    AutoHideTaskbar = '작업표시줄 자동 숨기기 (Dock 처럼)'
    Transparency    = '투명 효과'
}
# UI 옵션 (카탈로그 앱 — 설치되어 있을 때만 켜고 끔)
$script:AppUiOptions = @('quicklook', 'flow', 'windhawk')   # seelen 은 셸 계층(LiteWin.Shell.ps1)이 관리

$script:PersonalizeKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$script:StuckRectsKey  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StuckRects3'

function Get-UiSnapshotEntries {
    @(
        @{ Path = $script:PersonalizeKey; Name = 'AppsUseLightTheme' }
        @{ Path = $script:PersonalizeKey; Name = 'SystemUsesLightTheme' }
        @{ Path = $script:PersonalizeKey; Name = 'EnableTransparency' }
        @{ Path = $script:StuckRectsKey;  Name = 'Settings' }
    )
}

function Set-TaskbarAutoHide([bool]$On) {
    $e = Get-RegValueEntry -Path $script:StuckRectsKey -Name 'Settings'
    if (-not $e -or $e.Type -ne 'Binary') { return }
    try {
        $b = [Convert]::FromBase64String([string]$e.Value)
        if ($b.Length -le 8) { return }
        $b[8] = if ($On) { 0x03 } else { 0x02 }
        Set-RegValue $script:StuckRectsKey 'Settings' $b Binary
    } catch { Write-LWLog "작업표시줄 자동 숨기기 설정 실패: $($_.Exception.Message)" WARN }
}


# ------------------------------------------------------------------ 앱 시작 프로그램 켜고 끄기
function Set-AppStartupState {
    <# Run 항목 중 실행 파일 이름이 $Match 인 것을 '시작 프로그램' 사용/사용 안 함 (작업 관리자와 같은 방식) #>
    param([Parameter(Mandatory)][string]$Match, [bool]$Enabled, [switch]$NoStop)
    $pairs = @(
        @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'; Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
    )
    $found = $null
    foreach ($p in $pairs) {
        $props = Get-ItemProperty $p.Run -ErrorAction SilentlyContinue
        if (-not $props) { continue }
        foreach ($prop in $props.PSObject.Properties) {
            if ($prop.Name -like 'PS*') { continue }
            if ("$($prop.Value)" -like "*$Match*") {
                $bytes = New-Object byte[] 12
                $bytes[0] = if ($Enabled) { 0x02 } else { 0x03 }
                if (-not $Enabled) { [BitConverter]::GetBytes([DateTime]::Now.ToFileTime()).CopyTo($bytes, 4) }
                Set-RegValue $p.Approved $prop.Name $bytes Binary
                $found = "$($prop.Value)"
            }
        }
    }
    $procName = [IO.Path]::GetFileNameWithoutExtension($Match)
    if ($NoStop) { return [bool]$found }   # 시작 프로그램 등록만 바꾸고 실행 중인 프로그램은 그대로
    if ($Enabled) {
        if ($found -and -not (Get-Process $procName -ErrorAction SilentlyContinue)) {
            # Run 값은 "경로" 인자 형태 → cmd 로 그대로 실행
            Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', "start `"`" $found" -WindowStyle Hidden
        }
    } else {
        Get-Process $procName -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    return [bool]$found
}

function Set-UiApps {
    param([string[]]$EnabledIds = @())
    $catalog = Get-LWCatalog
    foreach ($id in $script:AppUiOptions) {
        $app = $catalog.apps | Where-Object id -eq $id
        if (-not $app) { continue }
        $on = $EnabledIds -contains $id
        if ($app.service) {
            $svc = Get-Service $app.service -ErrorAction SilentlyContinue
            if ($svc) {
                if ($on) { Set-Service $app.service -StartupType Automatic; Start-Service $app.service -ErrorAction SilentlyContinue }
                else     { Stop-Service $app.service -Force -ErrorAction SilentlyContinue; Set-Service $app.service -StartupType Disabled }
            }
        } elseif ($app.startupMatch) {
            [void](Set-AppStartupState -Match $app.startupMatch -Enabled $on)
        }
    }
}

# ------------------------------------------------------------------ 모드 전환
function Set-LWMode {
    <#
    .PARAMETER Mode       Lite | MacInput | MacUI
    .PARAMETER UiOptions  MacUI 일 때 켤 항목: DarkMode, AutoHideTaskbar, Transparency, quicklook, flow, windhawk
    .PARAMETER Keys       MacKeys 옵션 (CapsLockToHangul, OptionWordMove, CmdQuitApp, MacFKeys, StandardFKeys, GameAutoOff)
    .PARAMETER Shell      셸 옵션 (ClassicTaskbar, ClassicStart: 라이트/맥 입력용 / Caption: off|traffic|fullscreen: 맥 UI용)
    #>
    param(
        [Parameter(Mandatory)][ValidateSet('Lite', 'MacInput', 'MacUI')][string]$Mode,
        [string[]]$UiOptions = @(),
        [bool]$NaturalMouseWheel = $true,
        [hashtable]$Keys = @{},
        [hashtable]$Shell = @{}
    )
    $prev = Get-LWState
    Write-LWLog "모드 전환: $($prev.Mode) → $Mode"

    # ---- 입력 ----
    if ($Mode -eq 'Lite') {
        Disable-MacKeys
        if (-not (Restore-RegSnapshot -Name 'pointer')) { Reset-PointerSettings -UserRoot 'HKCU:' }
        [void](Set-NaturalMouseWheel -Enable $false)
    } else {
        Save-RegSnapshot -Name 'pointer' -Entries (Get-MacPointerSnapshotEntries)
        Set-MacPointerSettings -UserRoot 'HKCU:'
        [void](Set-NaturalMouseWheel -Enable $NaturalMouseWheel)
        $spot = if (($Mode -eq 'MacUI') -and ($UiOptions -contains 'flow')) { 'flow' } else { 'windows' }
        $cfg = @{ Spotlight = $spot }
        foreach ($k in 'CapsLockToHangul', 'OptionWordMove', 'CmdQuitApp', 'MacFKeys', 'StandardFKeys', 'GameAutoOff') { if ($Keys.ContainsKey($k)) { $cfg[$k] = [bool]$Keys[$k] } }
        Set-MacKeysConfig @cfg
        Enable-MacKeys
    }

    # ---- UI ----
    if ($Mode -eq 'MacUI') {
        Save-RegSnapshot -Name 'ui' -Entries (Get-UiSnapshotEntries)
        $dark = [int](-not ($UiOptions -contains 'DarkMode'))
        Set-RegValue $script:PersonalizeKey 'AppsUseLightTheme' $dark
        Set-RegValue $script:PersonalizeKey 'SystemUsesLightTheme' $dark
        Set-RegValue $script:PersonalizeKey 'EnableTransparency' ([int]($UiOptions -contains 'Transparency'))
        Set-TaskbarAutoHide ($UiOptions -contains 'AutoHideTaskbar')
        Set-UiApps -EnabledIds $UiOptions
    } elseif ($prev.Mode -eq 'MacUI') {
        [void](Restore-RegSnapshot -Name 'ui')
        Set-UiApps -EnabledIds @()
    }
    # 셸 옵션 저장 → 탐색기 재시작 → 셸 구성요소 적용 (로그인 때도 같은 값으로 다시 적용됨)
    $shellOpts = Get-LWShellOptions -State $prev
    foreach ($k in $Shell.Keys) { $shellOpts | Add-Member -NotePropertyName $k -NotePropertyValue $Shell[$k] -Force }
    $prev | Add-Member -NotePropertyName Shell -NotePropertyValue $shellOpts -Force
    $prev | Add-Member -NotePropertyName Mode -NotePropertyValue $Mode -Force
    Start-LWShell -State $prev -Apply -RestartExplorer

    $prev | Add-Member -NotePropertyName Mode -NotePropertyValue $Mode -Force
    $prev | Add-Member -NotePropertyName UiOptions -NotePropertyValue @($UiOptions) -Force
    $prev | Add-Member -NotePropertyName NaturalMouseWheel -NotePropertyValue $NaturalMouseWheel -Force
    $prev | Add-Member -NotePropertyName Keys -NotePropertyValue $Keys -Force
    Set-LWState $prev
    Write-LWLog '모드 전환 완료 (마우스/트랙패드·작업표시줄 일부는 재부팅/로그아웃 후 완전히 반영)'
}
