<#
    로그인할 때마다 실행 (HKLM Run "LiteWinShell"). 현재 사용자의 모드에 맞게
    클래식 작업표시줄 / Win7 시작 메뉴 / 창 버튼 오버레이를 켜거나 끈다.
#>
$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Shell.ps1')
# 탐색기가 완전히 뜰 때까지 잠깐 기다린다 (작업표시줄이 생긴 뒤 RetroBar 가 숨겨야 함)
for ($i = 0; $i -lt 30 -and -not (Get-Process explorer -ErrorAction SilentlyContinue); $i++) { Start-Sleep -Milliseconds 500 }
Start-Sleep -Seconds 2
Start-LWShell
