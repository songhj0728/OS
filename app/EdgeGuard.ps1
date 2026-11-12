<#
    부팅 시 SYSTEM 으로 실행되는 감시 작업 ("LiteWin Edge Guard").
    Windows 기능 업데이트 등으로 Edge 브라우저가 다시 설치되면 다시 제거하고 리다이렉트를 재등록한다.
#>
$ErrorActionPreference = 'Continue'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Edge.ps1')

$machine = Join-Path $script:LWRoot 'machine.json'
$cfg = if (Test-Path $machine) { Get-Content $machine -Raw -Encoding UTF8 | ConvertFrom-Json } else { $null }
if ($cfg -and -not $cfg.RemoveEdge) { exit 0 }

if (Test-EdgeInstalled) {
    Write-LWLog 'Edge 재설치 감지 → 다시 제거' -File 'EdgeGuard.log'
    Remove-EdgeBrowser -Quiet | Out-Null
} else {
    Remove-EdgeShortcuts
}
if (-not $cfg -or $cfg.EdgeRedirect) { Register-EdgeRedirect }
