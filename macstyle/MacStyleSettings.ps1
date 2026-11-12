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
# 키보드 (AutoHotkey v2 + MacKeys.ahk)
# ---------------------------------------------------------------------------
function Find-AutoHotkey {
    foreach ($c in "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
                   "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
                   "$env:ProgramFiles\AutoHotkey-v2\AutoHotkey64.exe") {
        if (Test-Path $c) { return $c }
    }
    return $null
}

function Install-AutoHotkey {
    $exe = Find-AutoHotkey
    if ($exe) { return $exe }
    if (Invoke-Winget -Id 'AutoHotkey.AutoHotkey' -Scope machine) {
        $exe = Find-AutoHotkey
        if ($exe) { return $exe }
    }
    Write-LWLog 'winget 실패 → AutoHotkey 공식 zip 으로 설치' WARN
    $zip  = Join-Path $env:TEMP 'ahk-v2.zip'
    $dest = "$env:ProgramFiles\AutoHotkey-v2"
    Invoke-WebRequest -UseBasicParsing -Uri 'https://www.autohotkey.com/download/ahk-v2.zip' -OutFile $zip
    $sig = $null
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip -Force
    $exe = Find-AutoHotkey
    if ($exe) {
        $sig = Get-AuthenticodeSignature $exe
        if ($sig.Status -ne 'Valid') { Write-LWLog "AutoHotkey 서명 확인 실패($($sig.Status)) — 삭제" ERROR; Remove-Item $dest -Recurse -Force; return $null }
    }
    return $exe
}

function Get-MacKeysTaskName { "LiteWin MacKeys ($env:USERNAME)" }

function Set-MacKeysConfig {
    <# 사용자별 MacKeys.ini (AHK 스크립트가 시작할 때 읽음) #>
    param(
        [bool]$CapsLockToHangul = $true,
        [bool]$OptionWordMove   = $true,
        [bool]$CmdQuitApp       = $true,
        [ValidateSet('windows', 'flow')][string]$Spotlight = 'windows'
    )
    New-Item -ItemType Directory -Path $script:LWUserDir -Force | Out-Null
    $ini = @"
[MacKeys]
CapsLockToHangul=$([int]$CapsLockToHangul)
OptionWordMove=$([int]$OptionWordMove)
CmdQuitApp=$([int]$CmdQuitApp)
Spotlight=$Spotlight
"@
    # AHK IniRead 는 UTF-16LE 를 가장 안정적으로 읽는다
    [IO.File]::WriteAllText((Join-Path $script:LWUserDir 'MacKeys.ini'), $ini, [Text.Encoding]::Unicode)
}

function Enable-MacKeys {
    <# AHK 설치 → 로그인 시 관리자 권한 자동 실행 작업 등록 → 즉시 시작 #>
    $ahk = Install-AutoHotkey
    if (-not $ahk) { throw 'AutoHotkey 설치 실패 (인터넷 연결 확인)' }
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
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" -ErrorAction SilentlyContinue |
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
}
