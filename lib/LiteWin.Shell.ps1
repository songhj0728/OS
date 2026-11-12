<#
    LiteWin 셸 계층: 모드별로 화면 껍데기를 켜고 끈다.
      라이트 / 맥 입력 : 클래식 작업표시줄(RetroBar) + Win7 시작 메뉴(Open-Shell)   ← Win11 작업표시줄 숨김
      맥 입력 + UI     : Win11 작업표시줄(가운데) + Windhawk Dock(선택) + 창 버튼 오버레이(LiteWinCaption)
    Windows 쪽 작업표시줄/시작 메뉴는 지우지 않고 그대로 둔다(업데이트 안전). RetroBar 가 실행되면 자동으로 숨는다.
    로그인 시 app\Start-LiteWinShell.ps1 이 Start-LWShell 을 호출해 다시 적용한다 → 재부팅/로그아웃 후에도 유지.
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:CaptionExe = Join-Path $script:LWRoot 'bin\LiteWinCaption.exe'

function Get-RetroBarExe {
    foreach ($p in "$env:ProgramFiles\RetroBar\RetroBar.exe", "${env:ProgramFiles(x86)}\RetroBar\RetroBar.exe",
                   "$env:LOCALAPPDATA\Programs\RetroBar\RetroBar.exe") {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-OpenShellExe {
    foreach ($p in "$env:ProgramFiles\Open-Shell\StartMenu.exe", "${env:ProgramFiles(x86)}\Open-Shell\StartMenu.exe") {
        if (Test-Path $p) { return $p }
    }
    return $null
}

function Get-LWShellOptions {
    <# 상태 파일의 Shell 옵션 + 기본값 #>
    param($State = (Get-LWState))
    $o = [ordered]@{ ClassicTaskbar = $true; ClassicStart = $true; TaskbarLabels = $false; Caption = 'traffic' }
    if ($State.Shell) {
        foreach ($p in $State.Shell.PSObject.Properties) { $o[$p.Name] = $p.Value }
    }
    return [pscustomobject]$o
}

function Set-CaptionConfig {
    param([ValidateSet('traffic', 'fullscreen')][string]$Mode = 'traffic')
    New-Item -ItemType Directory -Path $script:LWUserDir -Force | Out-Null
    $ini = Join-Path $script:LWUserDir 'Caption.ini'
    if (Test-Path $ini) {
        # 사용자가 손댄 Exclude/Offsets 는 유지하고 Mode 만 바꾼다
        $text = Get-Content $ini -Raw -Encoding UTF8
        if ($text -match '(?m)^Mode=') { $text = $text -replace '(?m)^Mode=.*$', "Mode=$Mode" }
        else { $text = $text -replace '(?m)^\[Caption\]\s*$', "[Caption]`r`nMode=$Mode" }
        Set-Content $ini $text -Encoding UTF8
        return
    }
    @"
[Caption]
; traffic = 닫기/최소화/전체화면 3개, fullscreen = 전체화면 버튼만
Mode=$Mode
; 창 왼쪽 위에서의 위치 (96 DPI 기준 픽셀)
OffsetX=10
OffsetY=9
; 버튼을 붙이지 않을 프로그램 (쉼표로 구분)
Exclude=
; 전체화면을 F11 로 처리할 프로그램
F11Apps=chrome.exe,msedge.exe,firefox.exe,brave.exe,opera.exe,vivaldi.exe,whale.exe

[Offsets]
; 앱별 위치 조정. 예) chrome.exe=10,9
"@ | Set-Content $ini -Encoding UTF8
}

function Stop-ProcessByPath([string]$Name, [string]$PathLike = '') {
    Get-Process $Name -ErrorAction SilentlyContinue |
        Where-Object { -not $PathLike -or $_.Path -like $PathLike } |
        Stop-Process -Force -ErrorAction SilentlyContinue
}

function Set-OpenShellAutoStart([bool]$On) {
    $k = 'HKCU:\Software\OpenShell\StartMenu\Settings'
    Set-RegValue $k 'AutoStart' ([int]$On)
    if ($On) {
        if (-not (Get-RegValueEntry -Path $k -Name 'MenuStyle')) { Set-RegValue $k 'MenuStyle' 'Win7' String }   # Win7 2열 구조
        Set-RegValue $k 'EnableStartButton' 0   # 시작 단추는 RetroBar 것을 사용
    }
}

function Set-NativeTaskbarStyle([ValidateSet('Classic', 'Mac')][string]$Style, [bool]$Labels = $false) {
    <# 클래식: 왼쪽 정렬. 단추 펼쳐 보기(이름 표시, 묶지 않기)는 옵션 #>
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    if ($Style -eq 'Classic') {
        $glom = if ($Labels) { 2 } else { 0 }
        Set-RegValue $adv 'TaskbarAl' 0
        Set-RegValue $adv 'TaskbarGlomLevel' $glom
        Set-RegValue $adv 'MMTaskbarGlomLevel' $glom
    } else {
        Set-RegValue $adv 'TaskbarAl' 1
        Set-RegValue $adv 'TaskbarGlomLevel' 0
        Set-RegValue $adv 'MMTaskbarGlomLevel' 0
    }
}

function Start-LWShell {
    <#
        .SYNOPSIS 현재 모드에 맞게 셸 구성요소를 실행/종료 (로그인 시 + 모드 전환 시)
        .PARAMETER Apply  레지스트리 스타일 값까지 다시 쓴다(모드 전환 시). 로그인 때는 실행/종료만.
    #>
    param($State = (Get-LWState), [switch]$Apply)
    $mode = if ($State.Mode) { $State.Mode } else { 'Lite' }
    $o = Get-LWShellOptions -State $State
    $mac = $mode -eq 'MacUI'

    if ($Apply) { Set-NativeTaskbarStyle $(if ($mac) { 'Mac' } else { 'Classic' }) ([bool]$o.TaskbarLabels) }

    # ---- 클래식 작업표시줄 (RetroBar) ----
    $rb = Get-RetroBarExe
    if (-not $mac -and $o.ClassicTaskbar -and $rb) {
        if (-not (Get-Process RetroBar -ErrorAction SilentlyContinue)) { Start-Process $rb }
    } else {
        Stop-ProcessByPath 'RetroBar'   # 종료되면 Windows 작업표시줄이 다시 나타난다
    }

    # ---- Win7 시작 메뉴 (Open-Shell) ----
    $os = Get-OpenShellExe
    if ($os) {
        $want = (-not $mac) -and [bool]$o.ClassicStart
        if ($Apply -or $want) { Set-OpenShellAutoStart $want }
        if ($want) {
            if (-not (Get-Process StartMenu -ErrorAction SilentlyContinue)) { Start-Process $os -ArgumentList '-autorun' }
        } else {
            if (Get-Process StartMenu -ErrorAction SilentlyContinue) { & $os -exit 2>$null; Stop-ProcessByPath 'StartMenu' }
        }
    }

    # ---- 창 버튼 오버레이 ----
    $capOn = $mac -and $o.Caption -in 'traffic', 'fullscreen'
    if ($capOn -and (Test-Path $script:CaptionExe)) {
        if ($Apply) { Set-CaptionConfig -Mode $o.Caption; Stop-ProcessByPath 'LiteWinCaption' }
        if (-not (Get-Process LiteWinCaption -ErrorAction SilentlyContinue)) { Start-Process $script:CaptionExe }
    } else {
        Stop-ProcessByPath 'LiteWinCaption'
    }
}

function Register-LWShellLauncher {
    <# 모든 사용자 로그인 시 Start-LiteWinShell.ps1 실행 (HKLM Run, 관리자) #>
    $script = Join-Path $script:LWRoot 'app\Start-LiteWinShell.ps1'
    Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'LiteWinShell' `
        "powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`"" String
}
