<#
    설치 이미지에 미리 넣는 프로그램 받기 (Build-LiteWin.ps1 과 CI 가 공용으로 사용)
    호출하는 쪽에 있어야 하는 것: $Fast, $dlCache, $tmpDir, Test-FreshFile, Warn, Info, Get-WingetPath, Get-GitHubRelease, Save-VerifiedAsset
#>
# 설치 이미지에 미리 넣을 프로그램 (winget download = 매니페스트의 SHA-256 으로 검증된 공식 설치 파일)
#   설치 마지막 단계(SetupComplete)에서 인터넷 없이 무인 설치된다. Args 를 비우면 매니페스트의 설치 종류로 판단.
$Payloads = @(
    # Repo/Pattern: winget download 가 실패하면 GitHub 공식 릴리스에서 받는다. FallbackArgs: 그때 쓸 무인 설치 옵션
    @{ Name = 'mpc-be';     Id = 'MPC-BE.MPC-BE';               Args = ''; Repo = 'Aleksoid1978/MPC-BE'; Pattern = 'x64.*installer.*\.(zip|exe)$'; FallbackArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' }
    @{ Name = 'imageglass'; Id = 'DuongDieuPhap.ImageGlass';    Args = ''; Repo = 'd2phap/ImageGlass';   Pattern = 'x64\.msi$' }
    # RetroBar 1.22+ 실행에 필요. winget 이 실패하면 Microsoft 공식 최신 링크에서 받고 Microsoft 서명을 확인한다
    @{ Name = 'dotnet-desktop'; Id = 'Microsoft.DotNet.DesktopRuntime.10'; Args = '/install /quiet /norestart'
       Url = 'https://aka.ms/dotnet/10.0/windowsdesktop-runtime-win-x64.exe'; Signer = 'Microsoft Corporation' }
    @{ Name = 'retrobar';   Id = 'dremin.RetroBar';             Args = ''; Repo = 'dremin/RetroBar';     Pattern = 'Installer\.(zip|exe)$'; FallbackArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /ALLUSERS'; PortableDir = 'RetroBar' }
    @{ Name = 'openshell';  Id = 'Open-Shell.Open-Shell-Menu';  Args = '/qn ADDLOCAL=StartMenu' }   # Win7 시작 메뉴
)

function Get-SilentArgs([string]$type, [string]$yamlSilent) {
    switch -Regex ($type) {
        '^(msi|wix)$' { return '/qn /norestart' }
        '^inno$'      { return '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /ALLUSERS' }   # /ALLUSERS: 사용자별 설치 프로그램도 Program Files 로
        '^nullsoft$'  { return '/S' }
        '^burn$'      { return '/quiet /norestart' }
        default       { if ($yamlSilent) { return $yamlSilent } return $null }
    }
}

function Save-WingetPayloads([string]$Dest) {
    $winget = Get-WingetPath
    if (-not $winget) { Warn 'winget 이 없습니다 — 공식 링크/GitHub 릴리스에서만 받습니다' }
    $result = @()
    foreach ($p in $Payloads) {
        $dir = Join-Path $(if ($Fast) { $dlCache } else { $tmpDir }) "payload-$($p.Name)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $have = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Select-Object -First 1
        if (-not ($Fast -and $have -and (Test-FreshFile $have.FullName))) {
            Get-ChildItem $dir -File | Remove-Item -Force
            $wgOut = if (-not $winget) { 'winget 없음' } else { & $winget download --id $p.Id --exact --source winget --download-directory $dir `
                --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String }
        }
        $installer = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Select-Object -First 1
        $yaml = Get-ChildItem $dir -File -Filter *.yaml | Select-Object -First 1
        $fromGitHub = $false
        if (-not $installer -and $p.Url) {
            Warn "$($p.Id): winget 다운로드 실패 → 공식 링크에서 받습니다"
            try {
                $f = Join-Path $dir "$($p.Name).exe"
                Invoke-WebRequest -UseBasicParsing -Uri $p.Url -OutFile $f
                $sig = Get-AuthenticodeSignature $f
                if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch [regex]::Escape($p.Signer)) {
                    Remove-Item $f -Force; Warn "$($p.Id): 서명 확인 실패 — 사용하지 않음"
                } else { $installer = Get-Item $f; $fromGitHub = $true }
            } catch { Warn "$($p.Id): 공식 링크도 실패 — $($_.Exception.Message)" }
        }
        if (-not $installer -and $p.Repo) {
            $why = (("$wgOut" -split "`r?`n" | Where-Object { $_.Trim() -and $_ -notmatch '^[\s\-\\|/█▒]+$' } | Select-Object -Last 2) -join ' / ')
            Warn "$($p.Id): winget 다운로드 실패 ($why) → GitHub 공식 릴리스($($p.Repo))에서 받습니다"
            try {
                $rel = Get-GitHubRelease -Repo $p.Repo -AssetPattern $p.Pattern -DelayDays 0
                if ($rel) {
                    $f = Join-Path $dir $rel.AssetName
                    [void](Save-VerifiedAsset -Release $rel -OutFile $f -AllowUnverified)
                    if ($f -like '*.zip') {
                        # zip 안에 설치 프로그램이 있으면 꺼내 쓰고, 없으면(포터블) zip 그대로 넣는다
                        $x = Join-Path $dir 'x'; Expand-Archive $f $x -Force
                        $inner = Get-ChildItem $x -Recurse -File | Where-Object { $_.Extension -in '.exe', '.msi' -and $_.Name -match '(setup|install)' } | Select-Object -First 1
                        if ($inner) { Copy-Item $inner.FullName $dir -Force; Remove-Item $f -Force }
                        Remove-Item $x -Recurse -Force
                    }
                    $installer = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Select-Object -First 1
                    if (-not $installer -and (Test-Path $f) -and $p.PortableDir) { $installer = Get-Item $f }
                    $fromGitHub = [bool]$installer
                }
            } catch { Warn "$($p.Id): GitHub 에서도 실패 — $($_.Exception.Message)" }
        }
        if (-not $installer) { Warn "$($p.Id): 다운로드 실패 — 건너뜀 (설치 후 인터넷으로 받음)"; continue }
        $yamlText = if ($yaml) { Get-Content $yaml.FullName -Raw } else { '' }
        $type = if ($yamlText -match '(?m)^\s*InstallerType:\s*(\S+)') { $Matches[1].ToLower() } elseif ($installer.Extension -eq '.msi') { 'msi' } else { 'exe' }
        $silent = if ($yamlText -match '(?m)^\s*Silent:\s*(.+)$') { $Matches[1].Trim().Trim("'").Trim('"') } else { '' }
        $args2 = if ($p.Args) { $p.Args } else { Get-SilentArgs $type $silent }
        if ($installer.Extension -eq '.zip') { $type = 'zip'; $args2 = 'portable' }
        elseif (-not $args2 -and $fromGitHub) { $args2 = if ($installer.Extension -eq '.msi') { '/qn /norestart' } else { $p.FallbackArgs } }
        if (-not $args2 -and $installer.Extension -ne '.msi') { Warn "$($p.Id): 무인 설치 방법을 알 수 없음($type) — 건너뜀"; continue }
        $file = "$($p.Name)$($installer.Extension)"
        Copy-Item $installer.FullName (Join-Path $Dest $file) -Force
        $result += [ordered]@{ Name = $p.Name; Id = $p.Id; File = $file; Type = $type; Args = $args2; PortableDir = "$($p.PortableDir)" }
        Info ("{0}: {1} ({2}, {3:N1}MB)" -f $p.Name, $installer.Name, $type, ($installer.Length / 1MB))
    }
    return $result
}

