<#
    맥 스타일 입력(마우스/트랙패드/키보드) 공용 함수.
    - 빌드 시: 오프라인 Default 사용자 하이브에 포인터 설정만 적용 (Set-MacPointerSettings)
    - 설치 후: 모드 전환(lib\LiteWin.Modes.ps1)과 Install-MacStyle.ps1 이 사용

    예)
        . .\MacStyleSettings.ps1
        Set-MacPointerSettings -UserRoot 'HKCU:'
        Set-MacPointerSettings -UserRoot 'Registry::HKEY_LOCAL_MACHINE\LW_NTUSER'
#>
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Common.ps1')

# ---------------------------------------------------------------------------
# 마우스 가속 곡선
#   Windows "포인터 정확도 향상"은 5개 점(X=손 움직임 속도, Y=커서 이동량)으로 된 곡선을 쓴다.
#   값은 16.16 고정소수점을 8바이트 little-endian 으로 저장한다.
#   맥은 "느리게 움직이면 더 정밀, 빠르게 휘두르면 더 멀리" 가는 성향이라
#   첫 구간 기울기는 낮추고 뒤 구간 기울기는 높였다. (실측 복제가 아닌 근사치 — 취향대로 조절)
# ---------------------------------------------------------------------------
$script:WindowsDefaultCurve = @{
    X = @(0.0, 0.43, 1.25, 3.86, 40.0)
    Y = @(0.0, 1.07, 4.14, 18.98, 443.75)
}
$script:MacLikeCurve = @{
    X = @(0.0, 0.43, 1.25, 3.86, 40.0)
    Y = @(0.0, 0.70, 3.40, 19.50, 520.0)
}

$script:MouseKey    = 'Control Panel\Mouse'
$script:TouchpadKey = 'Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
$script:TouchpadValues = [ordered]@{
    TapsEnabled             = 1   # 탭하여 클릭
    TwoFingerTapEnabled     = 1   # 두 손가락 탭 = 오른쪽 클릭 (맥과 동일)
    RightClickZoneEnabled   = 0   # 오른쪽 아래 모서리 누르기 = 우클릭 끔 (맥엔 없음)
    PanEnabled              = 1   # 두 손가락 스크롤
    ScrollDirection         = 0   # 0 = 자연스러운 스크롤(손가락 내리면 화면이 올라감)
    ZoomEnabled             = 1   # 핀치 줌
    ThreeFingerSlideEnabled = 2   # 3손가락 좌우 = 데스크톱(Spaces) 전환, 위 = 작업보기(Mission Control)
    FourFingerSlideEnabled  = 1   # 4손가락 좌우 = 앱 전환
    AAPThreshold            = 1   # 손바닥 오입력 방지 민감도(0=가장 민감 ~ 3)
}

function ConvertTo-MouseCurveBytes {
    param([Parameter(Mandatory)][double[]]$Points)
    if ($Points.Count -ne 5) { throw '마우스 곡선은 점 5개가 필요합니다.' }
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($p in $Points) {
        $fixed = [int64][math]::Round($p * 65536)
        $bytes.AddRange([BitConverter]::GetBytes($fixed))   # x86/x64 = little-endian
    }
    return , $bytes.ToArray()
}

function Get-MacPointerSnapshotEntries {
    <# 모드 되돌리기용: 맥 입력이 바꾸는 HKCU 값 목록 #>
    $m = "HKCU:\$script:MouseKey"; $t = "HKCU:\$script:TouchpadKey"
    $list = foreach ($n in 'MouseSpeed', 'MouseThreshold1', 'MouseThreshold2', 'MouseSensitivity', 'SmoothMouseXCurve', 'SmoothMouseYCurve') {
        @{ Path = $m; Name = $n }
    }
    $list += foreach ($n in $script:TouchpadValues.Keys) { @{ Path = $t; Name = $n } }
    return $list
}

function Set-PointerCurve {
    param([Parameter(Mandatory)][string]$UserRoot, [Parameter(Mandatory)][hashtable]$Curve)
    $mouse = Join-Path $UserRoot $script:MouseKey
    Set-RegValue $mouse 'MouseSpeed'        '1'  String   # 1 = 포인터 정확도 향상(가속) 켬
    Set-RegValue $mouse 'MouseThreshold1'   '6'  String
    Set-RegValue $mouse 'MouseThreshold2'   '10' String
    Set-RegValue $mouse 'MouseSensitivity'  '10' String   # 포인터 속도(1~20). 기본 10
    Set-RegValue $mouse 'SmoothMouseXCurve' (ConvertTo-MouseCurveBytes $Curve.X) Binary
    Set-RegValue $mouse 'SmoothMouseYCurve' (ConvertTo-MouseCurveBytes $Curve.Y) Binary
}

function Set-MacTouchpad {
    <# 정밀 터치패드 — 설정 > 블루투스 및 장치 > 터치패드 와 같은 값. 로그아웃 후 반영 #>
    param([Parameter(Mandatory)][string]$UserRoot)
    $tp = Join-Path $UserRoot $script:TouchpadKey
    foreach ($k in $script:TouchpadValues.Keys) { Set-RegValue $tp $k $script:TouchpadValues[$k] }
}

function Set-MacPointerSettings {
    param([Parameter(Mandatory)][string]$UserRoot)
    Set-PointerCurve -UserRoot $UserRoot -Curve $script:MacLikeCurve
    Set-MacTouchpad  -UserRoot $UserRoot
}

function Reset-PointerSettings {
    <# 마우스 곡선을 윈도우 기본값으로 (스냅샷이 없을 때 사용) #>
    param([Parameter(Mandatory)][string]$UserRoot)
    Set-PointerCurve -UserRoot $UserRoot -Curve $script:WindowsDefaultCurve
}

function Set-NaturalMouseWheel {
    <#
        마우스 휠도 맥처럼 "자연스러운 스크롤" (관리자). 연결된 HID 마우스마다 FlipFlopWheel 설정.
        재연결/재부팅 후 반영. 새 마우스를 연결하면 다시 실행해야 한다.
    #>
    param([bool]$Enable = $true)
    $value = [int]$Enable
    $count = 0
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Enum\HID' -ErrorAction SilentlyContinue |
        Get-ChildItem -ErrorAction SilentlyContinue |
        ForEach-Object {
            $dp = Join-Path $_.PSPath 'Device Parameters'
            if ((Test-Path $dp) -and ($null -ne (Get-ItemProperty $dp -Name FlipFlopWheel -ErrorAction SilentlyContinue))) {
                Set-ItemProperty $dp -Name FlipFlopWheel -Value $value -Type DWord
                $count++
            }
        }
    return $count
}

# ---------------------------------------------------------------------------
# 키보드 (LiteWinKeys.exe = AutoHotkey v2 엔진 + MacKeys.ahk)
# ---------------------------------------------------------------------------
# 키 매핑 엔진: AutoHotkey v2 의 실행 파일 하나만 LiteWinKeys.exe 로 넣는다.
#   설치 프로그램을 쓰지 않으므로 시작 메뉴(Window Spy, Dash 등)·앱 목록·트레이 아이콘이 생기지 않는다.
#   '맥 입력'을 켤 때만 준비되고, 끄면 실행되지 않는다(라이트 모드에서는 아무것도 상주하지 않음).
$script:KeysExe = Join-Path $script:LWRoot 'bin\LiteWinKeys.exe'

function Find-AutoHotkey {
    if (Test-Path $script:KeysExe) { return $script:KeysExe }
    return $null
}

function Install-AutoHotkey {
    $exe = Find-AutoHotkey
    if ($exe) { return $exe }
    New-Item -ItemType Directory -Path (Split-Path $script:KeysExe) -Force | Out-Null
    $zip = Join-Path $script:LWRoot 'payload\autohotkey.zip'          # 설치 이미지에 넣어 둔 공식 zip (인터넷 없이 사용)
    if (-not (Test-Path $zip)) {
        # 없으면 GitHub 공식 릴리스(AutoHotkey/AutoHotkey)에서 받는다 (autohotkey.com 은 스크립트 다운로드를 봇 차단)
        . (Join-Path $PSScriptRoot '..\lib\LiteWin.Components.ps1')
        $rel = Get-GitHubRelease -Repo 'AutoHotkey/AutoHotkey' -AssetPattern '^AutoHotkey_2.*\.zip$' -DelayDays 0
        if (-not $rel) { return $null }
        $zip = Join-Path $env:TEMP 'litewin-ahk.zip'
        [void](Save-VerifiedAsset -Release $rel -OutFile $zip -AllowUnverified)
    }
    $x = Join-Path $env:TEMP ('litewin-ahk-' + [guid]::NewGuid().ToString('N'))
    Expand-Archive -Path $zip -DestinationPath $x -Force
    $src = Get-ChildItem $x -Recurse -Filter 'AutoHotkey64.exe' | Select-Object -First 1
    if ($src) {
        $sig = Get-AuthenticodeSignature $src.FullName
        if ($sig.Status -eq 'HashMismatch') { Write-LWLog 'AutoHotkey 실행 파일 서명 손상 — 사용하지 않음' ERROR }
        else { Copy-Item $src.FullName $script:KeysExe -Force }
    }
    Remove-Item $x -Recurse -Force -ErrorAction SilentlyContinue
    return (Find-AutoHotkey)
}

function Get-MacKeysTaskName { "LiteWin MacKeys ($env:USERNAME)" }

function Set-MacKeysConfig {
    <# 사용자별 MacKeys.ini (AHK 스크립트가 시작할 때 읽음) #>
    param(
        [bool]$CapsLockToHangul = $true,
        [bool]$OptionWordMove   = $true,
        [bool]$CmdQuitApp       = $true,
        [bool]$MacFKeys         = $true,    # F1~F12 = 맥 기본 기능
        [bool]$StandardFKeys    = $false,   # 맥 "표준 기능 키로 사용" (⌥+F 와 역할 교환)
        [bool]$GameAutoOff      = $false,   # 전체화면 게임에서 자동 끔 (기본: 맥처럼 항상 동일)
        [ValidateSet('windows', 'flow')][string]$Spotlight = 'windows'
    )
    New-Item -ItemType Directory -Path $script:LWUserDir -Force | Out-Null
    $ini = @"
[MacKeys]
CapsLockToHangul=$([int]$CapsLockToHangul)
OptionWordMove=$([int]$OptionWordMove)
CmdQuitApp=$([int]$CmdQuitApp)
MacFKeys=$([int]$MacFKeys)
StandardFKeys=$([int]$StandardFKeys)
GameAutoOff=$([int]$GameAutoOff)
Spotlight=$Spotlight
"@
    # AHK IniRead 는 UTF-16LE 를 가장 안정적으로 읽는다
    [IO.File]::WriteAllText((Join-Path $script:LWUserDir 'MacKeys.ini'), $ini, [Text.Encoding]::Unicode)
}

function Enable-MacKeys {
    <# AHK 설치 → 로그인 시 관리자 권한 자동 실행 작업 등록 → 즉시 시작 #>
    $ahk = Install-AutoHotkey
    if (-not $ahk) { throw '키 매핑 엔진 준비 실패 (설치 이미지에 없고 인터넷으로도 받지 못함)' }
    $script = Join-Path $script:LWRoot 'macstyle\MacKeys.ahk'
    if (-not (Test-Path $script)) { $script = Join-Path $PSScriptRoot 'MacKeys.ahk' }
    if (-not (Test-Path (Join-Path $script:LWUserDir 'MacKeys.ini'))) { Set-MacKeysConfig }

    $user = "$env:USERDOMAIN\$env:USERNAME"
    $action    = New-ScheduledTaskAction -Execute $ahk -Argument "`"$script`""
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName (Get-MacKeysTaskName) -TaskPath '\LiteWin\' -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Stop-MacKeysProcess
    Start-ScheduledTask -TaskName (Get-MacKeysTaskName) -TaskPath '\LiteWin\'
    Write-LWLog '맥 키보드 단축키 켬'
}

function Stop-MacKeysProcess {
    Get-CimInstance Win32_Process -Filter "Name LIKE 'LiteWinKeys%' OR Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*MacKeys.ahk*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

function Disable-MacKeys {
    <# 작업은 지우지 않고 '사용 안 함'으로 → 다시 켤 때 빠름 #>
    Disable-ScheduledTask -TaskName (Get-MacKeysTaskName) -TaskPath '\LiteWin\' -ErrorAction SilentlyContinue | Out-Null
    Stop-MacKeysProcess
    Write-LWLog '맥 키보드 단축키 끔'
}

function Remove-MacKeys {
    Unregister-ScheduledTask -TaskName (Get-MacKeysTaskName) -TaskPath '\LiteWin\' -Confirm:$false -ErrorAction SilentlyContinue
    Stop-MacKeysProcess
    # 다른 사용자가 맥 입력을 쓰지 않으면 엔진 파일도 지운다
    if (-not (Get-ScheduledTask -TaskPath '\LiteWin\' -TaskName 'LiteWin MacKeys*' -ErrorAction SilentlyContinue)) {
        Remove-Item $script:KeysExe -Force -ErrorAction SilentlyContinue
    }
}
