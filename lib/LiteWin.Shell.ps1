<#
    LiteWin 셸 계층: 모드별로 화면 껍데기를 켜고 끈다.
      라이트 / 맥 입력 : 클래식 작업표시줄(ExplorerPatcher Win10, 예비 RetroBar) + Win7/Win10 시작 메뉴
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
    # ClassicEngine: ep = ExplorerPatcher Win10 작업표시줄 / retrobar,  StartEngine: openshell = Win7 / ep = Win10
    $o = [ordered]@{ ClassicTaskbar = $true; ClassicEngine = 'ep'; ClassicStart = $true; StartEngine = 'openshell'; TaskbarLabels = $false; Caption = 'traffic' }
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

function Restart-Explorer {
    Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 2
    if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

# ------------------------------------------------------------------ Seelen UI (맥 UI: 상단 메뉴바 + Dock)
#   Store/winget 판은 MSIX 패키지라 실행은 shell:AppsFolder 로, 자동 시작은 패키지의 StartupTask 상태로 켜고 끈다.
function Get-SeelenApp {
    $pkg = Get-AppxPackage -Name '*Seelen*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($pkg) {
        $appId = 'App'
        try { $appId = @((Get-AppxPackageManifest $pkg).Package.Applications.Application)[0].Id } catch { }
        return [pscustomobject]@{ Kind = 'msix'; Pfn = $pkg.PackageFamilyName; Target = "shell:AppsFolder\$($pkg.PackageFamilyName)!$appId" }
    }
    foreach ($p in "$env:ProgramFiles\Seelen\Seelen UI\seelen-ui.exe", "$env:LOCALAPPDATA\Programs\Seelen UI\seelen-ui.exe") {
        if (Test-Path $p) { return [pscustomobject]@{ Kind = 'exe'; Pfn = $null; Target = $p } }
    }
    return $null
}

function Set-SeelenState([bool]$On) {
    $app = Get-SeelenApp
    if (-not $app) { return $false }
    if ($app.Pfn) {
        # 패키지 시작 프로그램 상태: 2 = 켬, 1 = 꺼짐(사용자)
        $base = "HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\$($app.Pfn)"
        foreach ($k in Get-ChildItem $base -ErrorAction SilentlyContinue) {
            if ($null -ne (Get-ItemProperty $k.PSPath -Name State -ErrorAction SilentlyContinue)) { Set-RegValue $k.PSPath 'State' $(if ($On) { 2 } else { 1 }) }
        }
    }
    $running = Get-Process -Name 'seelen-ui*', 'slu-service*' -ErrorAction SilentlyContinue
    if ($On -and -not $running) { Start-Process $app.Target }
    if (-not $On -and $running) { $running | Stop-Process -Force -ErrorAction SilentlyContinue }
    return $true
}

function Test-EPInstalled {
    Test-Path "$env:ProgramFiles\ExplorerPatcher\ExplorerPatcher.amd64.dll"
}

function Test-ExplorerCrashLoop {
    <# 최근 10분 안에 탐색기가 3번 이상 비정상 종료됐는지 (업데이트 후 ExplorerPatcher 비호환 등) #>
    try {
        $ev = Get-WinEvent -FilterHashtable @{ LogName = 'Application'; Id = 1000; StartTime = (Get-Date).AddMinutes(-10) } -ErrorAction Stop |
              Where-Object { $_.Message -match 'explorer\.exe' }
        return (@($ev).Count -ge 3)
    } catch { return $false }
}

function Set-EPValue([string]$Path, [string]$Name, [int]$Value) {
    <# 값이 바뀌었으면 $true (탐색기 재시작 필요) #>
    $cur = Get-RegValueEntry -Path $Path -Name $Name
    if ($cur -and [int]$cur.Value -eq $Value) { return $false }
    Set-RegValue $Path $Name $Value
    return $true
}

function Start-LWShell {
    <#
        .SYNOPSIS 현재 모드에 맞게 셸 구성요소를 적용 (로그인 시 + 모드 전환 시)
          클래식: ExplorerPatcher Win10 작업표시줄 (없거나 문제가 생기면 RetroBar) + Win7/Win10 시작 메뉴
          맥    : Windows 11 작업표시줄(가운데) + 창 버튼 오버레이
        .PARAMETER Apply           레지스트리 스타일 값까지 다시 쓴다(모드 전환 시)
        .PARAMETER RestartExplorer 값이 그대로여도 탐색기를 다시 시작
    #>
    param($State = (Get-LWState), [switch]$Apply, [switch]$RestartExplorer)
    $mode = if ($State.Mode) { $State.Mode } else { 'Lite' }
    $o = Get-LWShellOptions -State $State
    $mac = $mode -eq 'MacUI'
    $ep = Test-EPInstalled
    $restart = [bool]$RestartExplorer

    # ---- ExplorerPatcher 문제 감지 → RetroBar 로 자동 전환 ----
    if (-not $Apply -and $ep -and $o.ClassicEngine -eq 'ep' -and (Test-ExplorerCrashLoop)) {
        Write-LWLog '탐색기 반복 종료 감지 → 클래식 작업표시줄을 RetroBar 로 전환' WARN
        $o.ClassicEngine = 'retrobar'
        $State | Add-Member -NotePropertyName Shell -NotePropertyValue $o -Force
        Set-LWState $State
        $restart = $true
    }

    $engine = 'none'
    if (-not $mac -and $o.ClassicTaskbar) { $engine = if ($o.ClassicEngine -eq 'ep' -and $ep) { 'ep' } else { 'retrobar' } }
    $epStart = $ep -and -not $mac -and $o.ClassicStart -and $o.StartEngine -eq 'ep'

    if ($Apply) { Set-NativeTaskbarStyle $(if ($mac) { 'Mac' } else { 'Classic' }) ([bool]$o.TaskbarLabels) }

    # ---- ExplorerPatcher 설정 (HKCU) ----
    if ($ep) {
        $epKey = 'HKCU:\Software\ExplorerPatcher'
        if (Set-EPValue $epKey 'OldTaskbar' $(if ($engine -eq 'ep') { 2 } else { 0 })) { $restart = $true }   # 2 = Windows 10 (ExplorerPatcher), 0 = Windows 11
        [void](Set-EPValue $epKey 'UpdatePolicy' 2)                                                        # 2 = 자체 업데이트 확인 안 함 (LiteWin 이 관리)
        $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        if (Set-EPValue $adv 'Start_ShowClassicMode' ([int]$epStart)) { $restart = $true }                  # 1 = Windows 10 시작 메뉴
        if ($Apply -and $engine -eq 'ep') {
            $glom = if ($o.TaskbarLabels) { 2 } else { 0 }
            if (Set-EPValue $adv 'TaskbarGlomLevel' $glom) { $restart = $true }
        }
    }
    if ($restart) { Restart-Explorer }

    # ---- RetroBar (예비 클래식 작업표시줄) ----
    $rb = Get-RetroBarExe
    if ($engine -eq 'retrobar' -and $rb) {
        if (-not (Get-Process RetroBar -ErrorAction SilentlyContinue)) {
            if (-not (Get-ChildItem "$env:ProgramFiles\dotnet\shared\Microsoft.WindowsDesktop.App\10.*" -Directory -ErrorAction SilentlyContinue)) {
                Write-LWLog 'RetroBar 를 실행할 .NET 10 데스크톱 런타임이 없습니다 — LiteWin 설정에서 [적용] 을 누르면 설치합니다' WARN
            }
            $rp = Start-Process $rb -PassThru
            Start-Sleep -Seconds 4
            if ($rp.HasExited) { Write-LWLog "RetroBar 가 바로 종료됨 (코드 $($rp.ExitCode))" WARN }
        }
    } else {
        Stop-ProcessByPath 'RetroBar'
    }

    # ---- Win7 시작 메뉴 (Open-Shell) ----
    $os = Get-OpenShellExe
    if ($os) {
        $want = (-not $mac) -and [bool]$o.ClassicStart -and -not $epStart
        if ($Apply -or $want) { Set-OpenShellAutoStart $want }
        if ($want) {
            if (-not (Get-Process StartMenu -ErrorAction SilentlyContinue)) { Start-Process $os -ArgumentList '-autorun' }
        } else {
            if (Get-Process StartMenu -ErrorAction SilentlyContinue) { & $os -exit 2>$null; Stop-ProcessByPath 'StartMenu' }
        }
    }

    # ---- 맥 UI: Seelen UI (상단 메뉴바 + Dock) ----
    $wantSeelen = $mac -and (@($State.UiOptions) -contains 'seelen')
    [void](Set-SeelenState $wantSeelen)

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
