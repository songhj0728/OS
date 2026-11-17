<#
.SYNOPSIS Windows 정품 인증이 "서버에 연결할 수 없음"으로 실패할 때 진단·복구 (관리자 PowerShell)
    시간 동기화, 관련 서비스, 인증 서버 연결, 프록시를 확인하고 다시 인증을 시도한다. 우회가 아니라 정상 인증용.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\tools\Repair-Activation.ps1
    powershell -ExecutionPolicy Bypass -File .\tools\Repair-Activation.ps1 -ProductKey XXXXX-XXXXX-XXXXX-XXXXX-XXXXX
#>
#Requires -RunAsAdministrator
param([string]$ProductKey)
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Activation.ps1')
if ($ProductKey) { Write-Host (Set-LWProductKey $ProductKey) }
Invoke-LWActivationRepair | ForEach-Object { Write-Host $_ }
