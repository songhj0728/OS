<#
    "LiteWin Components" 예약 작업 본체 (SYSTEM). 부팅 직후 / Windows Update 설치 직후 / 매일 실행.
    직접 실행:  powershell -ExecutionPolicy Bypass -File Update-LiteWinComponents.ps1 [-Force]
#>
param([switch]$Force)
$ErrorActionPreference = 'Continue'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Components.ps1')

$boot = $false
try {
    $up = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $boot = $up.TotalMinutes -lt 6
} catch { }

# 네트워크가 늦게 올라오는 경우를 위해 잠깐 기다린다 (없어도 기능 업데이트 보호는 동작)
[void](Test-Internet -WaitSeconds 60)
try { Invoke-LWComponentMaintenance -AtBoot:$boot -Force:$Force }
catch { Write-LWLog "구성요소 관리 실패: $_" ERROR -File 'Components.log' }
