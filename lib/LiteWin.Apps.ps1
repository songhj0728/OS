<#
    앱 카탈로그(apps\catalog.json) 읽기 + 설치
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

function Get-LWCatalog {
    $file = Join-Path (Split-Path -Parent $PSScriptRoot) 'apps\catalog.json'
    Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
}

function Test-TpmSecureBoot {
    $tpm = $false; $sb = $false
    try { $t = Get-Tpm -ErrorAction Stop; $tpm = $t.TpmPresent -and $t.TpmReady } catch { }
    try { $sb = Confirm-SecureBootUEFI -ErrorAction Stop } catch { }
    [pscustomobject]@{ Tpm = $tpm; SecureBoot = $sb; Ok = ($tpm -and $sb) }
}

function Open-GpuDriverPage {
    $names = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | ForEach-Object Name)
    Write-LWLog ("그래픽 장치: " + ($names -join ', '))
    $pages = [ordered]@{
        'NVIDIA' = 'https://www.nvidia.com/ko-kr/software/nvidia-app/'
        'AMD|Radeon' = 'https://www.amd.com/ko/support/download/drivers.html'
        'Intel'  = 'https://www.intel.co.kr/content/www/kr/ko/support/detect.html'
    }
    $opened = 0
    foreach ($k in $pages.Keys) {
        if ($names -match $k) { Start-Process $pages[$k]; $opened++ }
    }
    if (-not $opened) { Write-LWLog '알려진 그래픽 장치를 찾지 못했습니다 (Windows Update 드라이버 사용)' WARN }
    return $true
}

function Install-LWApp {
    param([Parameter(Mandatory)]$App)
    if ($App.unavailable) { Write-LWLog "$($App.name): 아직 배포되지 않음 — 건너뜀" WARN; return $false }

    if ($App.requiresTpm) {
        $chk = Test-TpmSecureBoot
        if (-not $chk.Ok) { Write-LWLog "$($App.name): TPM=$($chk.Tpm) 보안부팅=$($chk.SecureBoot) — 설치는 되지만 게임 실행이 막힐 수 있습니다" WARN }
    }
    if ($App.storePage) { Start-Process $App.storePage; Write-LWLog "$($App.name): Store 페이지를 열었습니다"; return $true }
    if ($App.action -eq 'gpu-driver') { return (Open-GpuDriverPage) }

    $ok = $true
    foreach ($pkg in @($App.packages)) {
        $label = if ($pkg.name) { "$($App.name) / $($pkg.name)" } else { $App.name }
        Write-LWLog "설치: $label"
        if (-not (Invoke-Winget -Id $pkg.id -Source $pkg.source)) { $ok = $false }
    }
    return $ok
}

function Install-LWApps {
    <# .OUTPUTS 실패한 앱 이름 목록 #>
    param([string[]]$Ids)
    if (-not $Ids -or $Ids.Count -eq 0) { Write-LWLog '설치할 앱 없음 (건너뛰기)'; return @() }
    $catalog = Get-LWCatalog
    $failed = @()
    foreach ($id in $Ids) {
        $app = $catalog.apps | Where-Object id -eq $id
        if (-not $app) { Write-LWLog "카탈로그에 없는 앱: $id" WARN; continue }
        if (-not (Install-LWApp -App $app)) { $failed += $app.name }
    }
    return $failed
}
