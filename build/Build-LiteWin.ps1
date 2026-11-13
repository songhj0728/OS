#Requires -RunAsAdministrator
<#
.SYNOPSIS
    공식 Windows 11 ISO 로 가벼운 Pro 설치 ISO(LiteWin)를 만든다.

.DESCRIPTION
    Microsoft 공식 ISO(없으면 Microsoft 서버에서 직접 다운로드) → Pro 에디션만 추출
    → 번들앱/Office/Edge 패키지/불필요 기능 제거 → 광고·원격분석·Copilot 정책 적용
    → Chrome(기본 브라우저)·LiteWin 설정 앱·설치 후 스크립트 삽입 → autounattend.xml → 부팅 가능한 ISO.

    LiteWin 은 ISO 를 배포하지 않는다. 원본은 항상 Microsoft 에서 받고, 결과물은 본인 PC 에서만 쓴다.

    tiny11 류와 다른 점:
      * 시스템 파일을 강제로 지우지 않는다(WinSxS, 업데이트 스택, .NET, VC 런타임, 드라이버 저장소 유지)
        → Windows Update, 기능 추가/제거, sfc/DISM 복구가 정상 동작한다.
      * 32비트 프로그램은 WOW64 로 그대로 실행된다(32비트 프로그램을 켤 때만 메모리를 쓴다).
      * 정품 인증은 본인 Pro 라이선스로 한다. 결과 ISO 는 본인 PC 용으로만 쓰고 재배포하지 않는다.

    준비물:
      * Windows 10/11 PC, 관리자 권한 Windows PowerShell 5.1
      * 공식 Windows 11 ISO — 없으면 -IsoPath 를 빼고 실행하면 Microsoft 에서 직접 받는다
      * 인터넷 (ISO 다운로드, Chrome 설치 파일 포함)
      * Windows ADK 의 "배포 도구"(oscdimg.exe) — ISO 를 만들 때만 필요
      * 작업 폴더 여유 공간 약 25GB (NTFS)

.PARAMETER IsoPath           공식 Windows 11 ISO 경로 (생략 시 build\Get-WindowsIso.ps1 로 Microsoft 에서 다운로드)
.PARAMETER ProfileName       Standard(기본) / Minimal / Gaming — profiles\ 폴더의 이름
.PARAMETER OutputIso         결과 ISO 경로 (기본: 이 저장소\out\LiteWin-<프로필>.iso)
.PARAMETER WorkDir           작업 폴더 (공백 없는 경로, 기본 C:\LiteWinWork)
.PARAMETER Locale            지역/형식 (기본 ko-KR)
.PARAMETER InputLocale       키보드 (기본 Microsoft 한국어 IME)
.PARAMETER TimeZone          시간대 (기본 Korea Standard Time)
.PARAMETER BypassHardwareCheck  TPM2.0/보안부팅/CPU 검사 우회 (지원되지 않는 PC 용, 업데이트 보장 안 됨)
.PARAMETER SplitForFat32     install.wim 이 4GB 를 넘으면 install.swm 으로 분할 (FAT32 USB 용)
.PARAMETER OscdimgPath       oscdimg.exe 경로 (기본: ADK 설치 경로 자동 탐색)
.PARAMETER NoIso             ISO 를 만들지 않고 WorkDir\iso 폴더까지만 (Rufus 등으로 직접 USB 굽기)
.PARAMETER Fast              빠른 빌드(테스트용). WorkDir\cache 에 중간 결과를 저장해 다음 빌드부터 재사용:
                             ISO 풀기/Pro 추출, 앱 제거·레지스트리·Edge 제거까지 끝난 이미지, 내려받은 설치 파일(7일).
                             구성요소 정리(ResetBase)와 최대 압축을 생략한다 → ISO 가 조금 크다. 배포용은 -Fast 없이.
.PARAMETER SetupBackground   Windows 설치 프로그램(디스크 고르는 화면) 배경색. 기본은 배경화면과 어울리는 짙은 청회색 #2B2F38.
                             빈 문자열이면 바꾸지 않는다. -Fast 캐시가 있으면 cache 폴더를 지워야 색이 다시 적용된다.
.PARAMETER NoChrome          Chrome 을 넣지 않음 (Edge 도 제거하지 않음)

.EXAMPLE
    Set-ExecutionPolicy -Scope Process Bypass
    .\build\Build-LiteWin.ps1                       # ISO 를 Microsoft 에서 받아서 빌드
    .\build\Build-LiteWin.ps1 -IsoPath D:\Win11_24H2_Korean_x64.iso
.EXAMPLE
    .\build\Build-LiteWin.ps1 -IsoPath D:\Win11.iso -ProfileName Minimal -SplitForFat32
#>
[CmdletBinding()]
param(
    [string]$IsoPath,
    [string]$ProfileName = 'Standard',
    [string]$OutputIso,
    [string]$WorkDir = 'C:\LiteWinWork',
    [string]$Locale = 'ko-KR',
    [string]$InputLocale = '0412:{A028AE76-01B1-46C2-99C4-ACD9858AE02F}{B5FE1F02-D5F2-4445-9C03-C568F23C99A1}',
    [string]$TimeZone = 'Korea Standard Time',
    [switch]$BypassHardwareCheck,
    [switch]$SplitForFat32,
    [string]$OscdimgPath,
    [switch]$NoIso,
    [switch]$NoChrome,
    [switch]$Fast,
    [string]$SetupBackground = '#2B2F38',
    [switch]$KeepWorkDir
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # DISM cmdlet 진행표시줄이 매우 느려서 끔
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'OfflineTweaks.ps1')
. (Join-Path $PSScriptRoot 'OfflineEdge.ps1')
. (Join-Path $PSScriptRoot 'OfflineRegAccess.ps1')
. (Join-Path $PSScriptRoot 'SetupBackground.ps1')   # System.Drawing 도 여기서 불러온다
. (Join-Path $RepoRoot 'lib\LiteWin.Common.ps1')
. (Join-Path $RepoRoot 'lib\LiteWin.Assoc.ps1')
. (Join-Path $RepoRoot 'lib\LiteWin.Components.ps1')
$ChromeMsiUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'

# 설치 이미지에 미리 넣을 프로그램 (winget download = 매니페스트의 SHA-256 으로 검증된 공식 설치 파일)
#   설치 마지막 단계(SetupComplete)에서 인터넷 없이 무인 설치된다. Args 를 비우면 매니페스트의 설치 종류로 판단.
$Payloads = @(
    # Repo/Pattern: winget download 가 실패하면 GitHub 공식 릴리스에서 받는다. FallbackArgs: 그때 쓸 무인 설치 옵션
    @{ Name = 'mpc-be';     Id = 'MPC-BE.MPC-BE';               Args = ''; Repo = 'Aleksoid1978/MPC-BE'; Pattern = 'x64.*installer.*\.(zip|exe)$'; FallbackArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' }
    @{ Name = 'imageglass'; Id = 'DuongDieuPhap.ImageGlass';    Args = ''; Repo = 'd2phap/ImageGlass';   Pattern = 'x64\.msi$' }
    @{ Name = 'retrobar';   Id = 'dremin.RetroBar';             Args = ''; Repo = 'dremin/RetroBar';     Pattern = 'Installer\.(zip|exe)$'; FallbackArgs = '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-'; PortableDir = 'RetroBar' }
    @{ Name = 'dotnet-desktop'; Id = 'Microsoft.DotNet.DesktopRuntime.10'; Args = '/install /quiet /norestart' }   # RetroBar 실행에 필요
    @{ Name = 'openshell';  Id = 'Open-Shell.Open-Shell-Menu';  Args = '/qn ADDLOCAL=StartMenu' }   # Win7 시작 메뉴
)

function Get-SilentArgs([string]$type, [string]$yamlSilent) {
    switch -Regex ($type) {
        '^(msi|wix)$' { return '/qn /norestart' }
        '^inno$'      { return '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-' }
        '^nullsoft$'  { return '/S' }
        '^burn$'      { return '/quiet /norestart' }
        default       { if ($yamlSilent) { return $yamlSilent } return $null }
    }
}

function Save-WingetPayloads([string]$Dest) {
    $winget = Get-WingetPath
    if (-not $winget) { Warn 'winget 이 없어 설치 파일을 미리 넣지 못합니다 (첫 로그인 후 인터넷으로 설치됨)'; return @() }
    $result = @()
    foreach ($p in $Payloads) {
        $dir = Join-Path $(if ($Fast) { $dlCache } else { $tmpDir }) "payload-$($p.Name)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $have = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Select-Object -First 1
        if (-not ($Fast -and $have -and (Test-FreshFile $have.FullName))) {
            Get-ChildItem $dir -File | Remove-Item -Force
            $wgOut = & $winget download --id $p.Id --exact --source winget --download-directory $dir `
                --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String
        }
        $installer = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Select-Object -First 1
        $yaml = Get-ChildItem $dir -File -Filter *.yaml | Select-Object -First 1
        $fromGitHub = $false
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

$sw = [Diagnostics.Stopwatch]::StartNew()
function Step($msg)  { Write-Host ("`n[{0:mm\:ss}] == {1}" -f $sw.Elapsed, $msg) -ForegroundColor Cyan }
function Info($msg)  { Write-Host "    $msg" }
$script:BuildWarnings = New-Object System.Collections.Generic.List[string]
function Warn($msg)  { Write-Host "    ! $msg" -ForegroundColor Yellow; $script:BuildWarnings.Add($msg) }

# 빌드 기록: 화면에 나온 내용을 그대로 out\LiteWin-build.log 에 남긴다 (문제 생기면 이 파일 하나만 보내면 됨)
$BuildLog = Join-Path $RepoRoot 'out\LiteWin-build.log'
New-Item -ItemType Directory -Path (Split-Path $BuildLog) -Force | Out-Null
try { Start-Transcript -Path $BuildLog -Force | Out-Null } catch { }
function Write-BuildSummary([string]$result) {
    Write-Host ''
    if ($script:BuildWarnings.Count) {
        Write-Host "== 경고 $($script:BuildWarnings.Count)개 ==" -ForegroundColor Yellow
        $script:BuildWarnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    }
    Write-Host "== $result — 빌드 기록: $BuildLog ==" -ForegroundColor Cyan
}

# ============================================================== 0. 사전 점검
if ($env:OS -ne 'Windows_NT') { throw 'Windows 에서 실행해야 합니다 (DISM 필요).' }
if ($WorkDir -match '\s') { throw "WorkDir 에 공백이 없어야 합니다: $WorkDir" }
if (-not $OutputIso) { $OutputIso = Join-Path $RepoRoot "out\LiteWin-$ProfileName.iso" }
if (-not $IsoPath) {
    Step 'ISO 가 지정되지 않음 → Microsoft 에서 직접 다운로드'
    $IsoPath = & (Join-Path $PSScriptRoot 'Get-WindowsIso.ps1') | Select-Object -Last 1
}
if (-not (Test-Path $IsoPath -PathType Leaf)) { throw "ISO 파일이 없습니다: $IsoPath" }

$drive = (Split-Path -Qualifier $WorkDir).TrimEnd(':')
$free  = (Get-PSDrive $drive).Free / 1GB
if ($free -lt 25) { Warn ("{0}: 여유 공간 {1:N1}GB — 25GB 이상 권장" -f $drive, $free) }

if (-not $NoIso) {
    if (-not $OscdimgPath) {
        $OscdimgPath = @(
            "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
            "$env:ProgramFiles\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
            (Join-Path $RepoRoot 'tools\oscdimg.exe')
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $OscdimgPath -or -not (Test-Path $OscdimgPath)) {
        throw @"
oscdimg.exe 를 찾을 수 없습니다.
  - Windows ADK 설치 시 '배포 도구(Deployment Tools)'만 체크해서 설치하거나
    (winget install Microsoft.WindowsADK)
  - -OscdimgPath 로 직접 지정하거나
  - -NoIso 로 폴더까지만 만든 뒤 Rufus 로 USB 를 만드세요.
"@
    }
}

# ============================================================== 1. 프로필
Step "프로필 불러오기: $ProfileName"
$profileFile = Join-Path $RepoRoot "profiles\$ProfileName.psd1"
if (-not (Test-Path $profileFile)) { throw "프로필 없음: $profileFile" }
$common = Import-PowerShellDataFile (Join-Path $RepoRoot 'profiles\_common.psd1')
$prof   = Import-PowerShellDataFile $profileFile

function Merge-List($base, $add) { @(@($base) + @($add) | Where-Object { $_ } | Sort-Object -Unique) }
$cfg = [ordered]@{
    Name               = $prof.Name
    Description        = $prof.Description
    BuiltAt            = (Get-Date).ToString('s')
    RemoveAppx         = Merge-List $common.RemoveAppx $prof.AddRemoveAppx
    KeepAppx           = @($prof.KeepAppx)
    RemoveCapabilities = Merge-List $common.RemoveCapabilities $prof.AddRemoveCapabilities
    KeepCapabilities   = @($prof.KeepCapabilities)
    DisableFeatures    = Merge-List $common.DisableFeatures $prof.AddDisableFeatures
    DisableServices    = Merge-List $common.DisableServices $prof.AddDisableServices
    ManualServices     = Merge-List $common.ManualServices $prof.AddManualServices
    DisableTasks       = Merge-List $common.DisableTasks $prof.AddDisableTasks
}
foreach ($k in 'DisableHibernation', 'DisableSearchIndexing', 'DisableSysMain', 'RemoveOneDrive', 'IncludeChrome', 'RemoveEdge', 'ResetBase') {
    $cfg[$k] = if ($prof.Overrides -and $prof.Overrides.ContainsKey($k)) { [bool]$prof.Overrides[$k] } else { [bool]$common[$k] }
}
if ($NoChrome) { $cfg.IncludeChrome = $false }
if (-not $cfg.IncludeChrome) { $cfg.RemoveEdge = $false }   # 브라우저가 하나도 없게 되는 것 방지
$cfg.Defaults = if ($prof.Defaults) { $prof.Defaults } else { @{ Mode = 'Lite'; UiOptions = @(); Apps = @() } }
# 같은 서비스가 Disable/Manual 양쪽에 있으면 Disable 우선
$cfg.ManualServices = @($cfg.ManualServices | Where-Object { $cfg.DisableServices -notcontains $_ })
Info $cfg.Description

function Test-Prefix([string]$name, $patterns) {
    foreach ($p in @($patterns)) { if ($p -and $name.StartsWith($p, [StringComparison]::OrdinalIgnoreCase)) { return $true } }
    return $false
}

# ============================================================== 2. ISO 복사
$isoDir   = Join-Path $WorkDir 'iso'
$mountDir = Join-Path $WorkDir 'mount'
$tmpDir   = Join-Path $WorkDir 'tmp'

# ---- 빠른 빌드 캐시 (-Fast) ----
$cacheDir = Join-Path $WorkDir 'cache'
$dlCache  = Join-Path $cacheDir 'downloads'
function Get-ShortHash([string]$text) {
    $sha = [Security.Cryptography.SHA256]::Create()
    (-join ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text)) | ForEach-Object { $_.ToString('x2') })).Substring(0, 12)
}
function Test-FreshFile([string]$path, [int]$days = 7) {
    (Test-Path $path) -and ((Get-Item $path).LastWriteTime -gt (Get-Date).AddDays(-$days)) -and ((Get-Item $path).Length -gt 0)
}
$isoItem   = Get-Item (Resolve-Path $IsoPath).Path
$isoKey    = Get-ShortHash "$($isoItem.FullName)|$($isoItem.Length)|$($isoItem.LastWriteTimeUtc.Ticks)"
$baseCache = Join-Path $cacheDir "base-$isoKey"
# 이미지 단계(앱 제거/레지스트리/Edge)에 영향을 주는 것만 모아 키를 만든다 → 이 중 하나라도 바뀌면 그 단계를 다시 한다
$stageInput = @(
    $isoKey, [bool]$BypassHardwareCheck
    ($cfg.RemoveAppx -join ','), ($cfg.KeepAppx -join ','), ($cfg.RemoveCapabilities -join ','), ($cfg.KeepCapabilities -join ',')
    ($cfg.DisableFeatures -join ','), $cfg.RemoveOneDrive, $cfg.RemoveEdge
    (Get-FileHash (Join-Path $PSScriptRoot 'OfflineTweaks.ps1')).Hash
    (Get-FileHash (Join-Path $PSScriptRoot 'OfflineEdge.ps1')).Hash
    (Get-FileHash (Join-Path $PSScriptRoot 'OfflineRegAccess.ps1')).Hash
) -join '|'
$stageWim = Join-Path $cacheDir ("stage-{0}.wim" -f (Get-ShortHash $stageInput))
$baseHit  = [bool]$Fast -and (Test-Path (Join-Path $baseCache 'meta.json'))
$stageHit = $baseHit -and (Test-Path $stageWim)
if ($Fast) {
    $cfg.ResetBase = $false
    New-Item -ItemType Directory -Path $cacheDir, $dlCache -Force | Out-Null
}

function Save-MountedImage {
    # 이 프로세스가 이미지 안 파일을 붙잡고 있지 않도록 정리 후, 잠깐 기다리며 재시도
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    for ($try = 1; ; $try++) {
        try { Dismount-WindowsImage -Path $mountDir -Save -ErrorAction Stop | Out-Null; return }
        catch {
            if ($try -ge 3) { throw "마운트 해제 실패: $($_.Exception.Message) — 백신 실시간 검사나 탐색기 창이 $mountDir 안을 열고 있지 않은지 확인하세요." }
            Warn "마운트 해제 재시도 ($try/3): $($_.Exception.Message)"
            Start-Sleep -Seconds 10; [GC]::Collect()
        }
    }
}
$mounted  = $false
$hives    = New-Object System.Collections.Generic.List[string]

function Mount-Hives {
    $map = @{
        SOFTWARE = "$mountDir\Windows\System32\config\SOFTWARE"
        SYSTEM   = "$mountDir\Windows\System32\config\SYSTEM"
        NTUSER   = "$mountDir\Users\Default\NTUSER.DAT"
    }
    foreach ($h in $map.Keys) {
        & reg.exe load "HKLM\LW_$h" $map[$h] | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "레지스트리 하이브 로드 실패: $h" }
        $hives.Add("HKLM\LW_$h")
    }
}
function Dismount-Hives {
    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
    foreach ($h in @($hives)) {
        for ($i = 0; $i -lt 5; $i++) {
            & reg.exe unload $h 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { break }
            Start-Sleep -Seconds 2; [GC]::Collect()
        }
        if ($LASTEXITCODE -ne 0) { Warn "하이브 언로드 실패: $h (재부팅 후 'reg unload $h')" }
        else { [void]$hives.Remove($h) }
    }
}
function HivePath($hive, $path) { "Registry::HKEY_LOCAL_MACHINE\LW_$hive\$path" }

try {
    Step '작업 폴더 준비 (지난 실패로 남은 마운트/레지스트리 정리)'
    # 1) 지난 빌드가 남긴 오프라인 레지스트리 하이브
    foreach ($h in 'SOFTWARE', 'SYSTEM', 'NTUSER') {
        if (Test-Path "Registry::HKEY_LOCAL_MACHINE\LW_$h") {
            [GC]::Collect(); & reg.exe unload "HKLM\LW_$h" 2>$null | Out-Null
            if ($LASTEXITCODE -eq 0) { Warn "남아 있던 하이브 해제: LW_$h" } else { throw "남아 있던 하이브 LW_$h 를 해제할 수 없습니다. 재부팅 후 다시 실행하세요." }
        }
    }
    # 2) 작업 폴더 아래에 남은 마운트 (다른 프로그램이 쓰는 마운트는 건드리지 않음)
    $stale = @(Get-WindowsImage -Mounted -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$WorkDir*" })
    foreach ($m in $stale) {
        Warn "이전에 마운트된 이미지를 버리고 해제합니다: $($m.Path) ($($m.MountStatus))"
        try { Dismount-WindowsImage -Path $m.Path -Discard -ErrorAction Stop | Out-Null }
        catch { & dism.exe /English /Unmount-Image "/MountDir:$($m.Path)" /Discard | Out-Null }
    }
    if ($stale.Count) { & dism.exe /English /Cleanup-Mountpoints | Out-Null }
    if ((Test-Path $mountDir) -and (Get-ChildItem $mountDir -Force -ErrorAction SilentlyContinue | Select-Object -First 1)) {
        Warn '마운트 폴더에 남은 파일 정리'
        & takeown.exe /F $mountDir /R /A /D Y 2>&1 | Out-Null
        & icacls.exe $mountDir /grant '*S-1-5-32-544:F' /T /C /Q 2>&1 | Out-Null
        Remove-Item $mountDir -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $mountDir) { throw "마운트 폴더 $mountDir 를 비울 수 없습니다. 재부팅 후 다시 실행하세요." }
    }
    foreach ($d in $isoDir, $tmpDir) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
    New-Item -ItemType Directory -Path $isoDir, $mountDir, $tmpDir -Force | Out-Null

    if ($baseHit) {
        Step '빠른 빌드: 캐시된 ISO 내용 사용'
        & robocopy.exe (Join-Path $baseCache 'iso') $isoDir /E /MT:16 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "캐시 복사 실패 (robocopy $LASTEXITCODE)" }
    } else {
        Step "ISO 복사: $IsoPath"
        $disk = Mount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path -PassThru
        try {
            $letter = ($disk | Get-Volume).DriveLetter
            & robocopy.exe "$($letter):\" $isoDir /E /MT:16 /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "ISO 복사 실패 (robocopy $LASTEXITCODE)" }
        } finally {
            Dismount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path | Out-Null
        }
        Get-ChildItem $isoDir -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }
    }

    $chromeMsi = Join-Path $(if ($Fast) { $dlCache } else { $tmpDir }) 'chrome.msi'
    if ($cfg.IncludeChrome -and $Fast -and (Test-FreshFile $chromeMsi)) {
        Info 'Chrome 설치 파일: 캐시 사용'
    } elseif ($cfg.IncludeChrome) {
        Step 'Chrome 기업용 설치 파일 다운로드 (Google 공식)'
        Invoke-WebRequest -UseBasicParsing -Uri $ChromeMsiUrl -OutFile $chromeMsi
        $sig = Get-AuthenticodeSignature $chromeMsi
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Google') {
            throw "Chrome 설치 파일 서명 확인 실패: $($sig.Status) $($sig.SignerCertificate.Subject)"
        }
        Info ("서명 확인: {0}" -f $sig.SignerCertificate.Subject)
    }

    # ========================================================== 3. Pro 이미지 추출
    $srcWim = Join-Path $isoDir 'sources\install.wim'
    $srcEsd = Join-Path $isoDir 'sources\install.esd'
    $workWim = Join-Path $tmpDir 'pro.wim'
    if ($baseHit) {
        $meta = Get-Content (Join-Path $baseCache 'meta.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $uiLang = $meta.UiLang
        Step "빠른 빌드: 캐시된 이미지 사용 ($($meta.ImageName), 빌드 $($meta.Version))"
        if ($stageHit) { Info '앱 제거/레지스트리/Edge 제거까지 끝난 이미지를 재사용합니다'; Copy-Item $stageWim $workWim -Force }
        else { Info '제거 목록이나 레지스트리 정책이 바뀌어 이미지 단계를 다시 진행합니다'; Copy-Item (Join-Path $baseCache 'pro.wim') $workWim -Force }
    } else {
        Step 'Pro 에디션 찾기'
        $src = if (Test-Path $srcWim) { $srcWim } elseif (Test-Path $srcEsd) { $srcEsd } else { throw 'install.wim/esd 가 없습니다. 공식 Windows 11 ISO 인지 확인하세요.' }

        $pro = $null
        foreach ($img in Get-WindowsImage -ImagePath $src) {
            $d = Get-WindowsImage -ImagePath $src -Index $img.ImageIndex
            Info ("[{0}] {1} ({2}, {3})" -f $d.ImageIndex, $d.ImageName, $d.EditionId, $d.Architecture)
            if ($d.EditionId -eq 'Professional') { $pro = $d }
        }
        if (-not $pro) { throw 'Pro(Professional) 에디션이 없는 ISO 입니다.' }
        if ($pro.Architecture -ne 9) { throw 'x64 이미지가 아닙니다.' }   # 9 = amd64
        $uiLang = @($pro.Languages)[$pro.DefaultLanguageIndex]
        Info "선택: [$($pro.ImageIndex)] $($pro.ImageName) / 언어 $uiLang / 빌드 $($pro.Version)"

        Export-WindowsImage -SourceImagePath $src -SourceIndex $pro.ImageIndex `
            -DestinationImagePath $workWim -CompressionType $(if ($Fast) { 'fast' } else { 'max' }) -CheckIntegrity | Out-Null

        if ($Fast) {
            Step '빠른 빌드: 원본(ISO 내용 + Pro 이미지)을 캐시에 저장'
            Get-ChildItem $cacheDir -Directory -Filter 'base-*' | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Get-ChildItem $cacheDir -File -Filter 'stage-*.wim' | Remove-Item -Force -ErrorAction SilentlyContinue
            New-Item -ItemType Directory -Path (Join-Path $baseCache 'iso') -Force | Out-Null
            & robocopy.exe $isoDir (Join-Path $baseCache 'iso') /E /MT:16 /XF install.wim install.esd /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
            Copy-Item $workWim (Join-Path $baseCache 'pro.wim') -Force
            @{ UiLang = $uiLang; Version = "$($pro.Version)"; ImageName = $pro.ImageName } | ConvertTo-Json |
                Set-Content (Join-Path $baseCache 'meta.json') -Encoding UTF8    # 마지막에 써서 '완성' 표시
        }
    }

    # ========================================================== 3-1. 설치 프로그램 배경
    #   빠른 빌드 캐시에는 원본 boot.wim 이 들어 있으므로, 매번 여기서 바꾼다 (색을 바꿔도 바로 반영)
    #   Windows 설치 화면 배경은 boot.wim 안 sources\background_*.bmp(또는 .png) 이다. 두 이미지(WinPE, Setup) 모두 확인한다.
    if ($SetupBackground) {
        # 이 단계가 실패해도 빌드는 계속한다 (원래 설치 화면이 나올 뿐)
        try {
            $color = ConvertFrom-HexColor $SetupBackground
            Step ("설치 프로그램 배경색: #{0:X2}{1:X2}{2:X2}" -f $color.R, $color.G, $color.B)
            $bootWim = Join-Path $isoDir 'sources\boot.wim'
            $bootMount = Join-Path $WorkDir 'mountboot'
            $replaced = 0
            foreach ($bi in @(Get-WindowsImage -ImagePath $bootWim | Sort-Object ImageIndex)) {
                if (Test-Path $bootMount) { Remove-Item $bootMount -Recurse -Force -ErrorAction SilentlyContinue }
                New-Item -ItemType Directory -Path $bootMount -Force | Out-Null
                try {
                    Mount-WindowsImage -ImagePath $bootWim -Index $bi.ImageIndex -Path $bootMount | Out-Null
                    $found = @(Get-ChildItem (Join-Path $bootMount 'sources') -File -ErrorAction SilentlyContinue |
                               Where-Object { $_.Name -match '^background.*\.(bmp|png|jpg)$' })
                    Info ("[{0}] {1}: {2}" -f $bi.ImageIndex, $bi.ImageName, $(if ($found) { ($found.Name -join ', ') } else { '배경 파일 없음' }))
                    foreach ($f in $found) {
                        $tmpImg = Join-Path $tmpDir ("setupbg-{0}-{1}" -f $bi.ImageIndex, $f.Name)
                        $made = New-SolidImageLike -Template $f.FullName -Color $color -OutFile $tmpImg
                        & takeown.exe /F $f.FullName /A 2>&1 | Out-Null
                        & icacls.exe $f.FullName /grant '*S-1-5-32-544:F' /C /Q 2>&1 | Out-Null
                        Copy-Item $tmpImg $f.FullName -Force
                        Info ("  - {0} ({1}x{2}) 교체" -f $f.Name, $made.Width, $made.Height)
                        $replaced++
                    }
                    [GC]::Collect(); [GC]::WaitForPendingFinalizers()
                    if ($found) { Dismount-WindowsImage -Path $bootMount -Save | Out-Null } else { Dismount-WindowsImage -Path $bootMount -Discard | Out-Null }
                } catch {
                    Warn "설치 프로그램 배경 변경 실패 ([$($bi.ImageIndex)]): $($_.Exception.Message)"
                    Dismount-WindowsImage -Path $bootMount -Discard -ErrorAction SilentlyContinue | Out-Null
                }
            }
            if (-not $replaced) { Warn '설치 프로그램 배경 파일을 찾지 못했습니다 — 위 [1]/[2] 줄을 알려주세요' }
        } catch { Warn "설치 프로그램 배경 단계 건너뜀: $($_.Exception.Message)" }
    }

    # ========================================================== 4. 마운트
    Step '이미지 마운트'
    Mount-WindowsImage -ImagePath $workWim -Index 1 -Path $mountDir | Out-Null
    $mounted = $true

    if (-not $stageHit) {
    # ========================================================== 5. 앱 제거
    Step '기본 앱(AppX) 제거'
    foreach ($pkg in Get-AppxProvisionedPackage -Path $mountDir) {
        if ((Test-Prefix $pkg.DisplayName $cfg.RemoveAppx) -and -not (Test-Prefix $pkg.DisplayName $cfg.KeepAppx)) {
            try {
                Remove-AppxProvisionedPackage -Path $mountDir -PackageName $pkg.PackageName -ErrorAction Stop | Out-Null
                Info "- $($pkg.DisplayName)"
            } catch { Warn "제거 실패: $($pkg.DisplayName) — $($_.Exception.Message)" }
        }
    }

    Step '선택적 기능(Capability) 제거'
    foreach ($cap in Get-WindowsCapability -Path $mountDir | Where-Object State -eq 'Installed') {
        if ((Test-Prefix $cap.Name $cfg.RemoveCapabilities) -and -not (Test-Prefix $cap.Name $cfg.KeepCapabilities)) {
            try {
                Remove-WindowsCapability -Path $mountDir -Name $cap.Name -ErrorAction Stop | Out-Null
                Info "- $($cap.Name)"
            } catch { Warn "제거 실패: $($cap.Name) — $($_.Exception.Message)" }
        }
    }

    Step 'Windows 기능(OptionalFeature) 끄기'
    $features = Get-WindowsOptionalFeature -Path $mountDir
    foreach ($fname in $cfg.DisableFeatures) {
        $f = $features | Where-Object FeatureName -eq $fname
        if ($f -and $f.State -eq 'Enabled') {
            try {
                Disable-WindowsOptionalFeature -Path $mountDir -FeatureName $fname -NoRestart -ErrorAction Stop | Out-Null
                Info "- $fname"
            } catch { Warn "끄기 실패: $fname — $($_.Exception.Message)" }
        }
    }

    # ========================================================== 6. 오프라인 레지스트리
    Step '레지스트리 정책 적용 (광고/원격분석/Copilot/추천 끄기)'
    Mount-Hives
    try {
        $tweaks = @($script:OfflineRegTweaks)
        if ($BypassHardwareCheck) { $tweaks += $script:OfflineRegBypass }
        # 보호된 키는 권한을 얻어 다시 시도하고, 그래도 안 되면 건너뛴다 (서비스 등은 설치 후 PostInstall 에서 다시 적용됨)
        $skipped = @()
        foreach ($t in $tweaks) {
            $path = HivePath $t.Hive $t.Path
            $ok = Invoke-OfflineRegWrite -RegPath $path -Action { Set-RegValue -Path $path -Name $t.Name -Value $t.Value -Type $t.Type }
            if (-not $ok) { $skipped += "$($t.Hive)\$($t.Path)\$($t.Name)" }
        }
        Info "값 $($tweaks.Count - $skipped.Count)/$($tweaks.Count)개 적용"
        foreach ($x in $skipped) { Warn "권한 문제로 건너뜀: $x" }
        foreach ($k in $script:OfflineRegDeleteKeys) {
            $p = HivePath $k.Hive $k.Path
            if (-not (Test-Path -LiteralPath $p)) { continue }
            if (Invoke-OfflineRegWrite -RegPath $p -Action { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop }) { Info "- 키 삭제: $($k.Path)" }
            else { Warn "권한 문제로 키 삭제 건너뜀: $($k.Path)" }
        }
        foreach ($v in $script:OfflineRegDeleteValues) {
            if ($v.Profile -and -not $cfg[$v.Profile]) { continue }
            $p = HivePath $v.Hive $v.Path
            if (Get-ItemProperty -LiteralPath $p -Name $v.Name -ErrorAction SilentlyContinue) {
                $n = $v.Name
                if (Invoke-OfflineRegWrite -RegPath $p -Action { Remove-ItemProperty -LiteralPath $p -Name $n -Force -ErrorAction Stop }) { Info "- 값 삭제: $($v.Path)\$n" }
                else { Warn "권한 문제로 값 삭제 건너뜀: $($v.Path)\$n" }
            }
        }
        if ($cfg.RemoveEdge) {
            Step 'Edge 브라우저를 설치 이미지에서 제거 (WebView2 유지)'
            $er = Remove-EdgeFromImage -MountDir $mountDir -HivePath ${function:HivePath}
            foreach ($x in $er.Removed) { Info "- $x" }
            Info "'연결 프로그램' 목록에서 Edge 항목 $($er.OpenWithCleaned)개 제거"
            foreach ($x in @($er.Skipped)) { Warn "권한 문제로 건너뜀: $x" }
        }
        # 맥 스타일 포인터 값은 여기서 넣지 않는다: 첫 로그인 마법사에서 고르고,
        # '라이트 윈도우' 로 되돌릴 때 원래 Windows 값을 복원할 수 있어야 하기 때문.
    } finally {
        Dismount-Hives
    }
    }   # if (-not $stageHit)

    if ($Fast -and -not $stageHit) {
        Step '빠른 빌드: 정리된 이미지를 캐시에 저장 (다음 빌드부터 앱 제거/레지스트리 단계 생략)'
        Save-MountedImage
        $mounted = $false
        Get-ChildItem $cacheDir -File -Filter 'stage-*.wim' | Remove-Item -Force -ErrorAction SilentlyContinue
        Copy-Item $workWim $stageWim -Force
        Mount-WindowsImage -ImagePath $workWim -Index 1 -Path $mountDir | Out-Null
        $mounted = $true
    }

    # ========================================================== 7. 설치 후 스크립트 삽입
    Step '설치 후 스크립트 / LiteWin 설정 앱 / 맥 스타일 파일 복사'
    $scripts = Join-Path $mountDir 'Windows\Setup\Scripts'
    $lw      = Join-Path $mountDir 'ProgramData\LiteWin'
    New-Item -ItemType Directory -Path $scripts, "$lw\logs", "$lw\bin", "$lw\payload" -Force | Out-Null
    Copy-Item (Join-Path $RepoRoot 'setup\*') $scripts -Force
    foreach ($d in 'lib', 'app', 'apps', 'macstyle') {
        Copy-Item (Join-Path $RepoRoot $d) $lw -Recurse -Force
    }
    # 배경화면 + Windows 테마 (설정 > 개인 설정 > 테마 에 'LiteWin …' 으로 나타남)
    #   테마 하나에 배경화면과 다크/라이트 모드가 묶여 있어서, 고르면 둘이 같이 바뀐다 (별도 프로그램 없음)
    #   새 계정 기본값은 autounattend 의 CustomDefaultThemeFile = LiteWin 라이트
    $wpDir = Join-Path $mountDir 'Windows\Web\Wallpaper\LiteWin'
    New-Item -ItemType Directory -Path $wpDir -Force | Out-Null
    Copy-Item (Join-Path $RepoRoot 'assets\wallpapers\*') $wpDir -Force
    $themeDir = Join-Path $mountDir 'Windows\Resources\Themes'
    foreach ($th in @(
        @{ File = 'LiteWinLight.theme';  Name = 'LiteWin 라이트';      Wallpaper = 'wave_light.jpg'; Mode = 'Light'; Id = '{6F2B9B8E-2C1A-4C55-9E21-5A1F0B7C1A01}' }
        @{ File = 'LiteWinDark.theme';   Name = 'LiteWin 다크';        Wallpaper = 'wave_dark.jpg';  Mode = 'Dark';  Id = '{6F2B9B8E-2C1A-4C55-9E21-5A1F0B7C1A02}' }
        @{ File = 'LiteWinRibbon.theme'; Name = 'LiteWin 리본';        Wallpaper = 'ribbon.jpg';     Mode = 'Dark';  Id = '{6F2B9B8E-2C1A-4C55-9E21-5A1F0B7C1A03}' }
        @{ File = 'LiteWinShapes.theme'; Name = 'LiteWin 도형';        Wallpaper = 'shapes.jpg';     Mode = 'Light'; Id = '{6F2B9B8E-2C1A-4C55-9E21-5A1F0B7C1A04}' }
    )) {
        $text = @"
; LiteWin 테마 — 배경화면과 다크/라이트 모드를 함께 바꾼다
[Theme]
DisplayName=$($th.Name)
ThemeId=$($th.Id)

[Control Panel\Desktop]
Wallpaper=%SystemRoot%\Web\Wallpaper\LiteWin\$($th.Wallpaper)
TileWallpaper=0
WallpaperStyle=10
Pattern=

[VisualStyles]
Path=%ResourceDir%\Themes\Aero\Aero.msstyles
ColorStyle=NormalColor
Size=NormalSize
AutoColorization=1
ColorizationColor=0XC42B2F38
SystemMode=$($th.Mode)
AppMode=$($th.Mode)
VisualStyleVersion=10

[MasterThemeSelector]
MTSM=RJSPBS

[Sounds]
SchemeName=@%SystemRoot%\System32\mmres.dll,-800

[boot]
SCRNSAVE.EXE=
"@
        # .theme 은 UTF-16(유니코드)로 저장해야 한글 이름이 깨지지 않는다
        [IO.File]::WriteAllText((Join-Path $themeDir $th.File), $text, [Text.Encoding]::Unicode)
    }
    Info "테마 4개: LiteWin 라이트(기본) / 다크 / 리본 / 도형"

    # Windows 기본 배경화면 자체를 바꾼다 → 설치가 끝나면 바로 이 배경. Windows 기본 테마(밝게/어둡게)도 이 그림을 쓴다
    #   img0 = 기본(밝게) → wave_light, img19 = 어둡게 → wave_dark, 4K 폴더의 해상도별 사본, 잠금 화면 기본 img100
    $wpSrc = Join-Path $RepoRoot 'assets\wallpapers'
    $swaps = @()
    $swaps += Get-ChildItem (Join-Path $mountDir 'Windows\Web\Wallpaper\Windows') -File -Filter 'img0*.jpg' -ErrorAction SilentlyContinue | ForEach-Object { @{ T = $_.FullName; S = 'wave_light.jpg' } }
    $swaps += Get-ChildItem (Join-Path $mountDir 'Windows\Web\Wallpaper\Windows') -File -Filter 'img19*.jpg' -ErrorAction SilentlyContinue | ForEach-Object { @{ T = $_.FullName; S = 'wave_dark.jpg' } }
    $swaps += Get-ChildItem (Join-Path $mountDir 'Windows\Web\4K\Wallpaper\Windows') -File -Filter 'img0_*.jpg' -ErrorAction SilentlyContinue | ForEach-Object { @{ T = $_.FullName; S = 'wave_light.jpg' } }
    $swaps += Get-ChildItem (Join-Path $mountDir 'Windows\Web\4K\Wallpaper\Windows') -File -Filter 'img19_*.jpg' -ErrorAction SilentlyContinue | ForEach-Object { @{ T = $_.FullName; S = 'wave_dark.jpg' } }
    $swaps += Get-ChildItem (Join-Path $mountDir 'Windows\Web\Screen') -File -Filter 'img100.jpg' -ErrorAction SilentlyContinue | ForEach-Object { @{ T = $_.FullName; S = 'wave_light.jpg' } }
    $n = 0
    foreach ($w in $swaps) {
        & takeown.exe /F $w.T /A 2>&1 | Out-Null
        & icacls.exe $w.T /grant '*S-1-5-32-544:F' /C /Q 2>&1 | Out-Null
        try { Copy-Item (Join-Path $wpSrc $w.S) $w.T -Force -ErrorAction Stop; $n++ } catch { Warn "배경 교체 실패: $($w.T.Substring($mountDir.Length))" }
    }
    Info "Windows 기본 배경화면 교체: $n 개 (기본 = wave_light, 어둡게 = wave_dark, 잠금 화면)"
    # HKLM 정책 목록: 오프라인에서 권한 문제로 못 쓴 값이 있어도 설치 마지막 단계(SYSTEM)에서 다시 적용한다
    ConvertTo-Json -InputObject @($script:OfflineRegTweaks | Where-Object { $_.Hive -ne 'NTUSER' }) -Depth 3 |
        Out-File (Join-Path $lw 'policies.json') -Encoding utf8
    $cfg | ConvertTo-Json -Depth 5 | Out-File (Join-Path $lw 'profile.json') -Encoding utf8
    @{ RemoveEdge = $cfg.RemoveEdge; EdgeRedirect = $cfg.RemoveEdge; BrowserName = 'Google Chrome'; DefaultBrowser = 'chrome' } | ConvertTo-Json |
        Out-File (Join-Path $lw 'machine.json') -Encoding utf8

    # LiteWin 자체 프로그램 컴파일 (.NET Framework 내장 컴파일러, 외부 도구 불필요)
    Step 'LiteWin 프로그램 컴파일 (설정 실행 파일, 창 버튼, Edge 링크 리다이렉트)'
    #   별도 PowerShell 프로세스에서 이미지 밖(tmp\bin)에 컴파일한 뒤 복사한다.
    #   같은 프로세스에서 컴파일하면 만든 exe 가 이 프로세스에 로드되어 잠기고, 그 파일이 마운트 폴더 안에 있으면
    #   마지막 단계의 마운트 해제(Dismount -Save)가 실패한다.
    $toolOut = Join-Path $tmpDir 'bin'
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass `
        -File (Join-Path $PSScriptRoot 'Compile-LiteWinTools.ps1') -OutDir $toolOut | Out-Host
    $toolFail = @()
    foreach ($exe in 'LiteWinEdgeRedirect.exe', 'LiteWinCaption.exe', 'LiteWinSettings.exe') {
        $src = Join-Path $toolOut $exe
        if (Test-Path $src) { Copy-Item $src (Join-Path $lw "bin\$exe") -Force } else { $toolFail += $exe }
    }
    if ($toolFail.Count) { Warn ("컴파일 실패: " + ($toolFail -join ', ') + " — 해당 기능 없이 진행") }

    # 미리 넣는 프로그램 (MPC-BE, ImageGlass, RetroBar, Open-Shell, .NET 런타임)
    Step '내장 프로그램 설치 파일 받기 (winget, 해시 검증)'
    $payloadList = @(Save-WingetPayloads -Dest (Join-Path $lw 'payload'))
    # 맥 입력용 키 매핑 엔진(AutoHotkey v2 공식 zip) — 설치하지 않고 넣어만 둔다. '맥 입력'을 켤 때만 꺼내 쓴다.
    try {
        $ahkCached = Join-Path $dlCache 'autohotkey.zip'
        $ahkFile = Join-Path $lw 'payload\autohotkey.zip'
        if ($Fast -and (Test-FreshFile $ahkCached)) { Copy-Item $ahkCached $ahkFile -Force; Info 'autohotkey: 캐시 사용' }
        else {
            $ahkRel = Get-GitHubRelease -Repo 'AutoHotkey/AutoHotkey' -AssetPattern '^AutoHotkey_2.*\.zip$' -DelayDays 7
            if ($ahkRel) {
                [void](Save-VerifiedAsset -Release $ahkRel -OutFile $ahkFile -AllowUnverified)
                if ($Fast) { Copy-Item $ahkFile $ahkCached -Force }
                Info "autohotkey: $($ahkRel.Tag) (맥 입력을 켤 때만 사용)"
            }
        }
    } catch { Warn "AutoHotkey 받기 실패 — 맥 입력을 켤 때 인터넷으로 받음: $($_.Exception.Message)" }

    # ExplorerPatcher (Win10 클래식 작업표시줄) — GitHub 공식 릴리스, 배포 후 7일 지난 버전, SHA-256 확인
    try {
        $epCached = Join-Path $dlCache 'ep_setup.exe'
        $epUseCache = [bool]$Fast -and (Test-FreshFile $epCached)
        $epRel = if ($epUseCache) { [pscustomobject]@{ Tag = '캐시'; Sha256 = 'cached' } }
                 else { Get-GitHubRelease -Repo $script:EPRepo -Asset $script:EPAsset -DelayDays 7 }
        if ($epRel) {
            $epFile = Join-Path $lw 'payload\ep_setup.exe'
            if ($epUseCache) { Copy-Item $epCached $epFile -Force; $h = 'cached' }
            else {
                $h = Save-VerifiedAsset -Release $epRel -OutFile $epFile -AllowUnverified
                if ($Fast) { Copy-Item $epFile $epCached -Force }
            }
            if (-not $epRel.Sha256) { Warn "ExplorerPatcher $($epRel.Tag): 배포처 해시 없음 — SHA-256 $h 를 릴리스 페이지와 직접 비교하세요" }
            $payloadList += [ordered]@{ Name = 'explorerpatcher'; Id = $script:EPRepo; File = 'ep_setup.exe'; Type = 'exe'; Args = ''; Keep = $true }
            Info ("explorerpatcher: {0} ({1:N1}MB)" -f $epRel.Tag, ((Get-Item $epFile).Length / 1MB))
        } else { Warn 'ExplorerPatcher 릴리스를 찾지 못함 — 클래식 작업표시줄은 RetroBar 사용' }
    } catch { Warn "ExplorerPatcher 받기 실패 — 클래식 작업표시줄은 RetroBar 사용: $($_.Exception.Message)" }
    ConvertTo-Json -InputObject $payloadList -Depth 3 | Out-File (Join-Path $lw 'payload\payloads.json') -Encoding utf8

    # 시작 메뉴 > 클래식 제어판 (설정 앱으로 옮겨간 항목 중 클래식 창이 남아 있는 것)
    $cpDir = Join-Path $mountDir 'ProgramData\Microsoft\Windows\Start Menu\Programs\클래식 제어판'
    New-Item -ItemType Directory -Path $cpDir -Force | Out-Null
    $wshCp = New-Object -ComObject WScript.Shell
    foreach ($c in @(
        @('제어판', 'control.exe', ''), @('프로그램 및 기능', 'control.exe', 'appwiz.cpl'),
        @('네트워크 연결', 'control.exe', 'ncpa.cpl'), @('소리', 'control.exe', 'mmsys.cpl'),
        @('마우스', 'control.exe', 'main.cpl'), @('전원 옵션', 'control.exe', 'powercfg.cpl'),
        @('시스템 고급 설정', 'SystemPropertiesAdvanced.exe', ''), @('지역', 'control.exe', 'intl.cpl'),
        @('날짜 및 시간', 'control.exe', 'timedate.cpl'), @('인터넷 옵션', 'control.exe', 'inetcpl.cpl'),
        @('사용자 계정 (고급)', 'netplwiz.exe', ''), @('장치 관리자', 'mmc.exe', 'devmgmt.msc'),
        @('디스크 관리', 'mmc.exe', 'diskmgmt.msc'), @('서비스', 'mmc.exe', 'services.msc'),
        @('고급 방화벽', 'mmc.exe', 'wf.msc'), @('작업 스케줄러', 'mmc.exe', 'taskschd.msc'),
        @('이벤트 뷰어', 'mmc.exe', 'eventvwr.msc'),
        @('장치 및 프린터', 'explorer.exe', 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}'),
        @('모든 작업 (갓 모드)', 'explorer.exe', 'shell:::{ED7BA470-8E54-465E-825C-99712043E01C}')
    )) {
        $l = $wshCp.CreateShortcut((Join-Path $cpDir "$($c[0]).lnk"))
        $l.TargetPath = "C:\Windows\System32\$($c[1])"
        if ($c[1] -eq 'explorer.exe') { $l.TargetPath = 'C:\Windows\explorer.exe' }
        $l.Arguments = $c[2]
        $l.Save()
    }

    if ($cfg.IncludeChrome) {
        Copy-Item $chromeMsi (Join-Path $lw 'payload\chrome.msi') -Force
        Step '기본 앱: Edge 항목 → Chrome (Windows 기본 연결 파일 병합)'
        $oem = Join-Path $mountDir 'Windows\System32\OEMDefaultAssociations.xml'
        $merged = Join-Path $tmpDir 'DefaultAssociations.xml'
        Merge-DefaultAssociations -Source $oem -Output $merged -Browser @('ChromeHTML', 'Google Chrome')
        & dism.exe /English /Image:$mountDir "/Import-DefaultAppAssociations:$merged" | Out-Null
        if ($LASTEXITCODE -ne 0) { Warn "기본 앱 연결 가져오기 실패 (dism $LASTEXITCODE)" }
        # 작업표시줄 고정: 탐색기 + Chrome (Edge/Store 고정 제거)
        $shell = Join-Path $mountDir 'Users\Default\AppData\Local\Microsoft\Windows\Shell'
        New-Item -ItemType Directory -Path $shell -Force | Out-Null
        Copy-Item (Join-Path $RepoRoot 'unattend\LayoutModification.xml') $shell -Force
    }

    # 시작 메뉴 > LiteWin 설정
    $lnkPath = Join-Path $mountDir 'ProgramData\Microsoft\Windows\Start Menu\Programs\LiteWin 설정.lnk'
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    if (Test-Path (Join-Path $lw 'bin\LiteWinSettings.exe')) {
        $lnk.TargetPath = 'C:\ProgramData\LiteWin\bin\LiteWinSettings.exe'     # 콘솔 창 없이 바로 열림
    } else {
        $lnk.TargetPath = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
        $lnk.Arguments  = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\LiteWin\app\LiteWinSettings.ps1"'
    }
    $lnk.IconLocation = 'C:\Windows\System32\imageres.dll,109'
    $lnk.Description = '모드(라이트/맥 입력/맥 UI), 추가 앱, 브라우저 설정'
    $lnk.Save()

    # ========================================================== 8. 정리 + 저장
    if ($cfg.ResetBase) {
        Step '구성요소 저장소 정리 (/StartComponentCleanup /ResetBase) — 수 분~수십 분 걸림'
        & dism.exe /English /Image:$mountDir /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Host
        if ($LASTEXITCODE -ne 0) { Warn "정리 단계 경고 (dism $LASTEXITCODE) — 계속 진행" }
    }

    Step '이미지 저장 및 마운트 해제'
    Save-MountedImage
    $mounted = $false

    Remove-Item $srcWim, $srcEsd -Force -ErrorAction SilentlyContinue
    if ($Fast) {
        Step '빠른 빌드: 재압축 생략'
        Move-Item $workWim $srcWim -Force
    } else {
        Step '최대 압축으로 다시 내보내기'
        Export-WindowsImage -SourceImagePath $workWim -SourceIndex 1 -DestinationImagePath $srcWim `
            -CompressionType max -CheckIntegrity | Out-Null
        Remove-Item $workWim -Force
    }
    $wimGB = (Get-Item $srcWim).Length / 1GB
    Info ("install.wim = {0:N2} GB" -f $wimGB)

    if ($SplitForFat32 -and (Get-Item $srcWim).Length -gt 4GB - 1MB) {
        Step 'FAT32 용 분할 (install.swm)'
        Split-WindowsImage -ImagePath $srcWim -SplitImagePath (Join-Path $isoDir 'sources\install.swm') `
            -FileSize 3800 -CheckIntegrity | Out-Null
        Remove-Item $srcWim -Force
    }

    # ========================================================== 9. autounattend.xml
    Step 'autounattend.xml 생성'
    $xml = Get-Content (Join-Path $RepoRoot 'unattend\autounattend.template.xml') -Raw -Encoding UTF8
    $xml = $xml.Replace('{{UILANG}}', $uiLang).Replace('{{LOCALE}}', $Locale).
                Replace('{{INPUT}}', $InputLocale).Replace('{{TIMEZONE}}', $TimeZone)
    if ($BypassHardwareCheck) {
        $cmds = 'BypassTPMCheck', 'BypassSecureBootCheck', 'BypassRAMCheck', 'BypassCPUCheck' | ForEach-Object -Begin { $i = 0 } -Process {
            $i++
            "        <RunSynchronousCommand wcm:action=`"add`"><Order>$i</Order><Path>reg add HKLM\SYSTEM\Setup\LabConfig /v $_ /t REG_DWORD /d 1 /f</Path></RunSynchronousCommand>"
        }
        $xml = $xml.Replace('<!--BYPASS_PE-->', "<RunSynchronous>`r`n$($cmds -join "`r`n")`r`n      </RunSynchronous>")
    }
    $null = [xml]$xml   # XML 문법 검사
    [IO.File]::WriteAllText((Join-Path $isoDir 'autounattend.xml'), $xml, (New-Object Text.UTF8Encoding $false))

    # ========================================================== 10. ISO
    if ($NoIso) {
        Step "완료: $isoDir  (Rufus 등으로 이 폴더를 USB 에 굽거나 직접 ISO 로 만드세요)"
    } else {
        Step "ISO 만들기: $OutputIso"
        New-Item -ItemType Directory -Path (Split-Path $OutputIso) -Force | Out-Null
        $etfs = Join-Path $isoDir 'boot\etfsboot.com'
        $efi  = Join-Path $isoDir 'efi\microsoft\boot\efisys.bin'
        & $OscdimgPath -m -o -u2 -udfver102 -lLITEWIN "-bootdata:2#p0,e,b$etfs#pEF,e,b$efi" $isoDir $OutputIso | Out-Host
        if ($LASTEXITCODE -ne 0) { throw "oscdimg 실패 ($LASTEXITCODE)" }
        Info ("ISO = {0:N2} GB" -f ((Get-Item $OutputIso).Length / 1GB))
        if ($Fast) {
            # 캐시(WorkDir\cache)는 남기고 임시 폴더만 지운다
            foreach ($d in $isoDir, $tmpDir, $mountDir) { Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue }
            Info "캐시: $cacheDir (지우면 다음 빌드는 처음부터)"
        } elseif (-not $KeepWorkDir) { Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Step ("끝 (소요 {0:hh\:mm\:ss})" -f $sw.Elapsed)
    Write-BuildSummary '성공'
}
catch {
    Write-Host "`n오류: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    Write-BuildSummary '실패'
    throw
}
finally {
    if ($hives.Count) { Dismount-Hives }
    if ($mounted) {
        Warn '오류로 중단 — 마운트된 이미지를 변경 없이 해제합니다'
        Dismount-WindowsImage -Path $mountDir -Discard -ErrorAction SilentlyContinue | Out-Null
    }
    try { Stop-Transcript | Out-Null } catch { }
}
