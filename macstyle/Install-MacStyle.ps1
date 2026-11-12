<#
.SYNOPSIS
    현재 사용자에게 맥 스타일 키보드/마우스/트랙패드를 적용한다. (관리자 PowerShell)

.DESCRIPTION
    1) 마우스 가속 곡선 + 정밀 터치패드 제스처 (HKCU)
    2) (선택) 마우스 휠 자연스러운 스크롤 (HKLM, 연결된 마우스 전부)
    3) AutoHotkey v2 설치 (winget → 실패 시 공식 zip) 후 MacKeys.ahk 를
       "로그인 시 관리자 권한으로" 실행하는 예약 작업 등록
       (관리자 권한이어야 관리자 창에서도 단축키가 먹는다)

    설치된 PC 에서는 C:\ProgramData\LiteWin\macstyle 에서 실행된다.
    이 저장소를 그냥 받은 일반 윈도우에서도 그대로 실행할 수 있다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-MacStyle.ps1
    powershell -ExecutionPolicy Bypass -File .\Install-MacStyle.ps1 -NaturalMouseWheel:$false -SkipKeyboard
#>
[CmdletBinding()]
param(
    [bool]$NaturalMouseWheel = $true,
    [switch]$SkipKeyboard,
    [switch]$SkipPointer,
    [string]$InstallDir = "$env:ProgramData\LiteWin\macstyle"
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'MacStyleSettings.ps1')

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw '관리자 권한 PowerShell 에서 실행하세요.' }

function Write-Step($msg) { Write-Host "[MacStyle] $msg" -ForegroundColor Cyan }

# ---------------------------------------------------------------- 포인터
if (-not $SkipPointer) {
    Write-Step '마우스 가속 곡선 / 터치패드 제스처 적용'
    Set-MacPointerSettings -UserRoot 'HKCU:'
    if ($NaturalMouseWheel) {
        $n = Set-NaturalMouseWheel -Enable $true
        Write-Step "마우스 휠 방향 반전: 장치 $n 개 (재연결/재부팅 후 반영)"
    }
}

# ---------------------------------------------------------------- 키보드
function Find-AutoHotkey {
    $candidates = @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
        "$env:ProgramFiles\AutoHotkey-v2\AutoHotkey64.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Install-AutoHotkey {
    $exe = Find-AutoHotkey
    if ($exe) { return $exe }

    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        Write-Step 'winget 으로 AutoHotkey v2 설치'
        & $winget.Source install --id AutoHotkey.AutoHotkey -e --scope machine --silent `
            --accept-package-agreements --accept-source-agreements | Out-Host
        $exe = Find-AutoHotkey
        if ($exe) { return $exe }
    }

    Write-Step 'winget 실패 → 공식 zip 으로 설치'
    $zip  = Join-Path $env:TEMP 'ahk-v2.zip'
    $dest = "$env:ProgramFiles\AutoHotkey-v2"
    Invoke-WebRequest -UseBasicParsing -Uri 'https://www.autohotkey.com/download/ahk-v2.zip' -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $dest -Force
    Remove-Item $zip -Force
    return (Find-AutoHotkey)
}

if (-not $SkipKeyboard) {
    $ahk = Install-AutoHotkey
    if (-not $ahk) { throw 'AutoHotkey 설치 실패. 인터넷 연결 확인 후 다시 실행하세요.' }

    # 스크립트를 고정 위치로 복사 (사용자가 수정 가능)
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $target = Join-Path $InstallDir 'MacKeys.ahk'
    if ((Resolve-Path (Join-Path $here 'MacKeys.ahk')).Path -ne $target) {
        if (Test-Path $target) { Copy-Item $target "$target.bak" -Force }
        Copy-Item (Join-Path $here 'MacKeys.ahk') $target -Force
    }

    Write-Step "로그인 시 자동 실행 등록: $target"
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $taskName = "LiteWin MacKeys ($env:USERNAME)"
    $action    = New-ScheduledTaskAction -Execute $ahk -Argument "`"$target`""
    $trigger   = New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                    -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Start-ScheduledTask -TaskName $taskName
}

Write-Step '완료. 마우스/트랙패드는 로그아웃 후 다시 로그인하면 반영됩니다.'
Write-Step '단축키 잠시 끄기: Ctrl+Alt+Win+F12'
