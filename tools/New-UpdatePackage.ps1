<#
.SYNOPSIS LiteWin 온라인 업데이트 파일(LiteWin-update.zip)을 만든다. release 워크플로와 로컬에서 공용.
    내용: lib, app, apps, macstyle, bin(컴파일한 exe 3개), version.json
.EXAMPLE  .\tools\New-UpdatePackage.ps1 -OutDir out -Version 2026.11.17.1
#>
param(
    [Parameter(Mandatory)][string]$OutDir,
    [Parameter(Mandatory)][string]$Version,
    [string]$Commit = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$stage = Join-Path $OutDir 'package'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Path $stage -Force | Out-Null

foreach ($d in 'lib', 'app', 'apps', 'macstyle') { Copy-Item (Join-Path $repo $d) (Join-Path $stage $d) -Recurse -Force }

# exe 는 별도 프로세스에서 컴파일 (이 프로세스가 파일을 잡고 있지 않도록)
$bin = Join-Path $stage 'bin'
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass `
    -File (Join-Path $repo 'build\Compile-LiteWinTools.ps1') -OutDir $bin | Out-Host
foreach ($exe in 'LiteWinEdgeRedirect.exe', 'LiteWinCaption.exe', 'LiteWinSettings.exe') {
    if (-not (Test-Path (Join-Path $bin $exe))) { throw "컴파일 실패: $exe" }
}
Get-ChildItem $bin -Exclude *.exe | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

@{ Version = $Version; Commit = $Commit; Date = (Get-Date -Format 'yyyy-MM-dd'); Source = 'release' } | ConvertTo-Json |
    Out-File (Join-Path $stage 'version.json') -Encoding utf8

$zip = Join-Path $OutDir 'LiteWin-update.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[IO.Compression.ZipFile]::CreateFromDirectory($stage, $zip, [IO.Compression.CompressionLevel]::Optimal, $false)
Write-Host "만듦: $zip ($([math]::Round((Get-Item $zip).Length / 1KB)) KB)"
return $zip
