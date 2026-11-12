<#
.SYNOPSIS
    Microsoft 공식 서버에서 Windows 11 ISO 를 직접 내려받는다.

.DESCRIPTION
    LiteWin 은 수정된 ISO 를 배포하지 않는다. 사용자가 Microsoft 에서 원본 ISO 를 직접 받고,
    자기 PC 에서 Build-LiteWin.ps1 로 가공한다.

    다운로드 링크는 Microsoft 공식 다운로드 페이지와 같은 API 에서 받아오며
    (오픈소스 Fido v1.72 사용, Rufus 개발자가 관리), 파일은 Microsoft 서버
    (software.download.prss.microsoft.com)에서 바로 내려받는다.
    Microsoft 가 자동 다운로드를 막는 경우가 있어서, 실패하면 공식 다운로드 페이지를 열어준다.

.PARAMETER Language   ISO 언어 (Fido 표기, 기본 Korean)
.PARAMETER OutDir     저장 폴더 (기본: 다운로드 폴더)
.OUTPUTS  내려받은 ISO 의 전체 경로
#>
[CmdletBinding()]
param(
    [string]$Language = 'Korean',
    [string]$OutDir = (Join-Path $env:USERPROFILE 'Downloads'),
    [string]$Release = 'Latest'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$FidoVersion = 'v1.72'
$FidoUrl     = "https://raw.githubusercontent.com/pbatard/Fido/$FidoVersion/Fido.ps1"
$OfficialPage = 'https://www.microsoft.com/software-download/windows11'

function Open-OfficialPage($reason) {
    Write-Host "`n자동 다운로드를 할 수 없습니다: $reason" -ForegroundColor Yellow
    Write-Host '공식 다운로드 페이지를 엽니다. "Windows 11 디스크 이미지(ISO) 다운로드" → 한국어 → 64비트 다운로드 를 선택하세요.'
    Write-Host "받은 뒤:  .\build\Build-LiteWin.ps1 -IsoPath <받은 ISO 경로>"
    Start-Process $OfficialPage
    throw 'ISO 를 직접 내려받은 뒤 -IsoPath 로 다시 실행하세요.'
}

$tools = Join-Path $env:TEMP 'LiteWin-tools'
New-Item -ItemType Directory -Path $tools, $OutDir -Force | Out-Null
$fido = Join-Path $tools "Fido-$FidoVersion.ps1"

try {
    if (-not (Test-Path $fido)) {
        Write-Host "Fido $FidoVersion 받는 중 (Microsoft 공식 다운로드 링크 조회용)"
        Invoke-WebRequest -UseBasicParsing -Uri $FidoUrl -OutFile $fido
    }
    Write-Host "Microsoft 에서 Windows 11 ($Language, x64) 다운로드 링크 받는 중..."
    $url = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $fido `
        -Win 'Windows 11' -Rel $Release -Ed Pro -Lang $Language -Arch x64 -GetUrl 2>$null |
        Where-Object { $_ -match '^https://' } | Select-Object -Last 1
} catch {
    Open-OfficialPage $_.Exception.Message
}
if (-not $url) { Open-OfficialPage 'Microsoft 가 링크 요청을 거부했습니다 (잠시 후 다시 시도하거나 직접 받기)' }

$uri = [Uri]$url
if ($uri.Host -notlike '*.microsoft.com') { throw "Microsoft 서버가 아닌 링크입니다: $($uri.Host)" }
$name = [IO.Path]::GetFileName($uri.AbsolutePath)
if (-not $name.EndsWith('.iso')) { $name = 'Win11_x64.iso' }
$dest = Join-Path $OutDir $name

if (Test-Path $dest) {
    Write-Host "이미 있음: $dest"
} else {
    Write-Host "다운로드: $($uri.Host)/.../$name  (약 5~7GB)"
    Start-BitsTransfer -Source $url -Destination $dest -DisplayName 'Windows 11 ISO' -Description 'Microsoft'
}

$hash = (Get-FileHash $dest -Algorithm SHA256).Hash
Write-Host "`nSHA-256: $hash" -ForegroundColor Cyan
Write-Host "공식 페이지($OfficialPage) 아래쪽 '확인' 목록의 한국어 64비트 해시와 같은지 확인하세요."
return $dest
