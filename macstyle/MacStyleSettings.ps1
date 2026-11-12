<#
    맥 스타일 포인터(마우스/트랙패드) 설정 공용 함수.
    - 빌드 시: 오프라인 Default 사용자 하이브에 적용 → 새로 만드는 모든 계정이 기본으로 맥 스타일
    - 설치 후: 현재 사용자(HKCU)에 적용
    둘 다 같은 함수를 쓰도록 "레지스트리 루트 경로"만 바꿔서 호출한다.

    예)
        . .\MacStyleSettings.ps1
        Set-MacPointerSettings -UserRoot 'HKCU:'
        Set-MacPointerSettings -UserRoot 'Registry::HKEY_LOCAL_MACHINE\LW_NTUSER'
#>

# ---------------------------------------------------------------------------
# 마우스 가속 곡선
#   Windows "포인터 정확도 향상"은 5개 점(X=손 움직임 속도, Y=커서 이동량)으로 된 곡선을 쓴다.
#   값은 16.16 고정소수점을 8바이트 little-endian 으로 저장한다.
#   맥은 윈도우보다 "느리게 움직이면 더 정밀, 빠르게 휘두르면 더 멀리" 가는 성향이라
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

function Set-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('String', 'DWord', 'QWord', 'Binary', 'ExpandString', 'MultiString')]
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Set-PointerCurve {
    param(
        [Parameter(Mandatory)][string]$UserRoot,
        [Parameter(Mandatory)][hashtable]$Curve
    )
    $mouse = Join-Path $UserRoot 'Control Panel\Mouse'
    Set-RegValue $mouse 'MouseSpeed'        '1'  String   # 1 = 포인터 정확도 향상(가속) 켬
    Set-RegValue $mouse 'MouseThreshold1'   '6'  String
    Set-RegValue $mouse 'MouseThreshold2'   '10' String
    Set-RegValue $mouse 'MouseSensitivity'  '10' String   # 포인터 속도(1~20). 기본 10
    Set-RegValue $mouse 'SmoothMouseXCurve' (ConvertTo-MouseCurveBytes $Curve.X) Binary
    Set-RegValue $mouse 'SmoothMouseYCurve' (ConvertTo-MouseCurveBytes $Curve.Y) Binary
}

# ---------------------------------------------------------------------------
# 정밀 터치패드(Precision Touchpad) — 맥 트랙패드에 가깝게
#   설정 > 블루투스 및 장치 > 터치패드 에서 바꾸는 값과 같은 위치다.
#   반영은 로그아웃/재로그인 후. 값이 맞지 않으면 설정 앱에서 직접 바꾸면 그대로 덮어써진다.
# ---------------------------------------------------------------------------
function Set-MacTouchpad {
    param([Parameter(Mandatory)][string]$UserRoot)
    $tp = Join-Path $UserRoot 'Software\Microsoft\Windows\CurrentVersion\PrecisionTouchPad'
    Set-RegValue $tp 'TapsEnabled'             1   # 탭하여 클릭
    Set-RegValue $tp 'TwoFingerTapEnabled'     1   # 두 손가락 탭 = 오른쪽 클릭 (맥과 동일)
    Set-RegValue $tp 'RightClickZoneEnabled'   0   # 오른쪽 아래 모서리 누르기 = 우클릭 끔 (맥엔 없음)
    Set-RegValue $tp 'PanEnabled'              1   # 두 손가락 스크롤
    Set-RegValue $tp 'ScrollDirection'         0   # 0 = 자연스러운 스크롤(손가락 내리면 화면이 올라감)
    Set-RegValue $tp 'ZoomEnabled'             1   # 핀치 줌
    Set-RegValue $tp 'ThreeFingerSlideEnabled' 2   # 3손가락 좌우 = 데스크톱(Spaces) 전환, 위 = 작업보기(Mission Control)
    Set-RegValue $tp 'FourFingerSlideEnabled'  1   # 4손가락 좌우 = 앱 전환
    Set-RegValue $tp 'AAPThreshold'            1   # 손바닥 오입력 방지 민감도(0=가장 민감 ~ 3)
}

function Set-MacPointerSettings {
    <#
        .SYNOPSIS 맥 스타일 마우스 가속 + 트랙패드 제스처를 사용자 하이브에 적용
        .PARAMETER UserRoot  'HKCU:' 또는 로드한 오프라인 하이브 경로
    #>
    param([Parameter(Mandatory)][string]$UserRoot)
    Set-PointerCurve -UserRoot $UserRoot -Curve $script:MacLikeCurve
    Set-MacTouchpad  -UserRoot $UserRoot
}

function Reset-PointerSettings {
    <# .SYNOPSIS 마우스 곡선을 윈도우 기본값으로 되돌림 (터치패드는 설정 앱에서 조정) #>
    param([Parameter(Mandatory)][string]$UserRoot)
    Set-PointerCurve -UserRoot $UserRoot -Curve $script:WindowsDefaultCurve
}

function Set-NaturalMouseWheel {
    <#
        .SYNOPSIS 마우스 휠도 맥처럼 "자연스러운 스크롤"로 뒤집기 (관리자, 실제 설치된 PC에서만)
        .DESCRIPTION 연결된 HID 마우스마다 FlipFlopWheel 값을 바꾼다. 마우스를 다시 꽂거나 재부팅 후 반영.
                     새 마우스를 연결하면 이 함수를 다시 실행해야 한다.
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
