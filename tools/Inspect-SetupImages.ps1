<#
.SYNOPSIS
    ISO 의 boot.wim 안에서 Windows 설치 화면 배경으로 쓰일 만한 그림 파일을 찾아 목록으로 보여준다 (아무것도 바꾸지 않음).
    설치 화면 배경색이 바뀌지 않을 때 원인을 찾는 용도. 1~2분 걸린다.

.EXAMPLE  (관리자 PowerShell)
    powershell -ExecutionPolicy Bypass -File .\tools\Inspect-SetupImages.ps1 -IsoPath D:\Win11.iso
    → 화면에 나온 목록(또는 out\setup-images.txt)을 보내주세요.
#>
#Requires -RunAsAdministrator
param([Parameter(Mandatory)][string]$IsoPath, [string]$MountDir = 'C:\LiteWinInspect')
$ErrorActionPreference = 'Stop'
$out = Join-Path (Split-Path -Parent $PSScriptRoot) 'out\setup-images.txt'
New-Item -ItemType Directory -Path (Split-Path $out) -Force | Out-Null
$lines = New-Object System.Collections.Generic.List[string]
$disk = Mount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path -PassThru
try {
    $letter = ($disk | Get-Volume).DriveLetter
    $boot = "$($letter):\sources\boot.wim"
    foreach ($img in Get-WindowsImage -ImagePath $boot) {
        $lines.Add("== [$($img.ImageIndex)] $($img.ImageName)")
        New-Item -ItemType Directory -Path $MountDir -Force | Out-Null
        Mount-WindowsImage -ImagePath $boot -Index $img.ImageIndex -Path $MountDir -ReadOnly | Out-Null
        try {
            Get-ChildItem $MountDir -Recurse -File -ErrorAction SilentlyContinue -Include *.bmp, *.png, *.jpg |
                Where-Object { $_.Length -gt 20KB } | Sort-Object Length -Descending | Select-Object -First 40 |
                ForEach-Object { $lines.Add(("{0,10:N0}KB  {1}" -f ($_.Length / 1KB), $_.FullName.Substring($MountDir.Length))) }
            Get-ChildItem (Join-Path $MountDir 'sources') -File -Filter 'spwiz*' -ErrorAction SilentlyContinue |
                ForEach-Object { $lines.Add(("{0,10:N0}KB  {1}  (설치 마법사 그림 리소스)" -f ($_.Length / 1KB), $_.FullName.Substring($MountDir.Length))) }
        } finally {
            Dismount-WindowsImage -Path $MountDir -Discard | Out-Null
        }
    }
} finally {
    Dismount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path | Out-Null
    Remove-Item $MountDir -Recurse -Force -ErrorAction SilentlyContinue
}
$lines | Set-Content $out -Encoding UTF8
$lines | ForEach-Object { Write-Host $_ }
Write-Host "`n저장: $out" -ForegroundColor Cyan
