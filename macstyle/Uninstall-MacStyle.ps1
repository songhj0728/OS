<#
.SYNOPSIS 맥 스타일 설정을 되돌린다. (관리자 PowerShell)
    - MacKeys 예약 작업 제거 및 실행 중인 스크립트 종료
    - 마우스 가속 곡선 윈도우 기본값 복원
    - 마우스 휠 방향 원래대로
    터치패드 제스처는 설정 > 블루투스 및 장치 > 터치패드 에서 원하는 대로 바꾸면 된다.
    AutoHotkey 자체는 남겨둔다(제거: 설정 > 앱 또는 winget uninstall AutoHotkey.AutoHotkey).
#>
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $here 'MacStyleSettings.ps1')

$taskName = "LiteWin MacKeys ($env:USERNAME)"
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}
Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -like '*MacKeys.ahk*' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Reset-PointerSettings -UserRoot 'HKCU:'
$n = Set-NaturalMouseWheel -Enable $false
Write-Host "[MacStyle] 되돌림 완료 (마우스 장치 $n 개). 로그아웃 후 반영됩니다." -ForegroundColor Cyan
