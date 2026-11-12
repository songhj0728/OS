<#
.SYNOPSIS
    맥 입력(키보드/마우스/트랙패드)을 현재 사용자에게 켠다. (관리자 PowerShell)
    LiteWin 이 아닌 일반 Windows 에서도 이 저장소 폴더째로 받아 실행하면 동작한다.
    UI 스타일까지 쓰려면 app\LiteWinSettings.ps1 에서 '맥 입력 + UI' 를 고르세요.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\macstyle\Install-MacStyle.ps1
    powershell -ExecutionPolicy Bypass -File .\macstyle\Install-MacStyle.ps1 -NaturalMouseWheel:$false
#>
[CmdletBinding()]
param([bool]$NaturalMouseWheel = $true)

$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Modes.ps1')
if (-not (Test-LWAdmin)) { throw '관리자 권한 PowerShell 에서 실행하세요.' }

Set-LWMode -Mode MacInput -NaturalMouseWheel $NaturalMouseWheel
Write-Host '[MacStyle] 완료. 단축키 잠시 끄기: Ctrl+Alt+Win+F12 / 마우스·트랙패드는 로그아웃 후 반영' -ForegroundColor Cyan
