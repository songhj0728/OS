<#
.SYNOPSIS apps\catalog.json 의 winget/Store ID 가 실제로 존재하는지 확인 (설치하지 않음)
.EXAMPLE  powershell -ExecutionPolicy Bypass -File .\tools\Test-Catalog.ps1
#>
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Apps.ps1')
$winget = Get-WingetPath
if (-not $winget) { throw 'winget 이 필요합니다.' }
$catalog = Get-LWCatalog
$rows = foreach ($app in $catalog.apps) {
    foreach ($pkg in @($app.packages)) {
        & $winget show --id $pkg.id --exact --source $pkg.source --accept-source-agreements --disable-interactivity *> $null
        [pscustomobject]@{ App = $app.id; Source = $pkg.source; Id = $pkg.id; Found = ($LASTEXITCODE -eq 0) }
    }
}
$rows | Format-Table -AutoSize
$bad = @($rows | Where-Object { -not $_.Found })
if ($bad.Count) { Write-Host "확인 필요: $($bad.Count)개 — catalog.json 의 id 를 'winget search <이름>' 결과로 고치세요." -ForegroundColor Yellow }
else { Write-Host '모든 ID 확인됨' -ForegroundColor Green }
