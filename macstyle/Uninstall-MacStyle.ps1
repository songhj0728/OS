<#
.SYNOPSIS 맥 스타일을 끄고 처음 상태로 되돌린다. (관리자 PowerShell)
    - 맥 키보드 예약 작업 제거, 실행 중인 MacKeys 종료
    - 마우스/트랙패드/UI 값: 맥 스타일을 처음 켜기 전 스냅샷으로 복원 (없으면 Windows 기본값)
    AutoHotkey 자체는 남겨둔다 (제거: winget uninstall AutoHotkey.AutoHotkey)
#>
$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Modes.ps1')
if (-not (Test-LWAdmin)) { throw '관리자 권한 PowerShell 에서 실행하세요.' }

Set-LWMode -Mode Lite
Remove-MacKeys
Write-Host '[MacStyle] 되돌림 완료. 로그아웃 후 반영됩니다.' -ForegroundColor Cyan
