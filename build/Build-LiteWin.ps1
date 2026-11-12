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
    [switch]$KeepWorkDir
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # DISM cmdlet 진행표시줄이 매우 느려서 끔
$RepoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'OfflineTweaks.ps1')
. (Join-Path $RepoRoot 'lib\LiteWin.Common.ps1')
$ChromeMsiUrl = 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'

# 설치 이미지에 미리 넣을 프로그램 (winget download = 매니페스트의 SHA-256 으로 검증된 공식 설치 파일)
#   설치 마지막 단계(SetupComplete)에서 인터넷 없이 무인 설치된다. Args 를 비우면 매니페스트의 설치 종류로 판단.
$Payloads = @(
    @{ Name = 'autohotkey'; Id = 'AutoHotkey.AutoHotkey';       Args = '' }                         # 맥 입력
    @{ Name = 'mpc-be';     Id = 'MPC-BE.MPC-BE';               Args = '' }                         # 동영상 기본 (HEVC 등)
    @{ Name = 'imageglass'; Id = 'DuongDieuPhap.ImageGlass';    Args = '' }                         # .heic/.heif 기본
    @{ Name = 'retrobar';   Id = 'dremin.RetroBar';             Args = '' }                         # 클래식 작업표시줄
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
        $dir = Join-Path $tmpDir "payload-$($p.Name)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & $winget download --id $p.Id --exact --source winget --download-directory $dir `
            --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
        $installer = Get-ChildItem $dir -File | Where-Object { $_.Extension -in '.exe', '.msi' } | Select-Object -First 1
        $yaml = Get-ChildItem $dir -File -Filter *.yaml | Select-Object -First 1
        if (-not $installer) { Warn "$($p.Id): 다운로드 실패 — 건너뜀"; continue }
        $yamlText = if ($yaml) { Get-Content $yaml.FullName -Raw } else { '' }
        $type = if ($yamlText -match '(?m)^\s*InstallerType:\s*(\S+)') { $Matches[1].ToLower() } elseif ($installer.Extension -eq '.msi') { 'msi' } else { 'exe' }
        $silent = if ($yamlText -match '(?m)^\s*Silent:\s*(.+)$') { $Matches[1].Trim().Trim("'").Trim('"') } else { '' }
        $args2 = if ($p.Args) { $p.Args } else { Get-SilentArgs $type $silent }
        if (-not $args2 -and $installer.Extension -ne '.msi') { Warn "$($p.Id): 무인 설치 방법을 알 수 없음($type) — 건너뜀"; continue }
        $file = "$($p.Name)$($installer.Extension)"
        Copy-Item $installer.FullName (Join-Path $Dest $file) -Force
        $result += [ordered]@{ Name = $p.Name; Id = $p.Id; File = $file; Type = $type; Args = $args2 }
        Info ("{0}: {1} ({2}, {3:N1}MB)" -f $p.Name, $installer.Name, $type, ($installer.Length / 1MB))
    }
    return $result
}

$sw = [Diagnostics.Stopwatch]::StartNew()
function Step($msg)  { Write-Host ("`n[{0:mm\:ss}] == {1}" -f $sw.Elapsed, $msg) -ForegroundColor Cyan }
function Info($msg)  { Write-Host "    $msg" }
function Warn($msg)  { Write-Host "    ! $msg" -ForegroundColor Yellow }

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
    Step '작업 폴더 준비'
    if (Test-Path $mountDir) {
        if (Get-WindowsImage -Mounted | Where-Object { $_.Path -eq $mountDir }) {
            Warn '이전에 마운트된 이미지를 버리고 해제합니다'
            Dismount-WindowsImage -Path $mountDir -Discard | Out-Null
        }
    }
    foreach ($d in $isoDir, $tmpDir) { if (Test-Path $d) { Remove-Item $d -Recurse -Force } }
    New-Item -ItemType Directory -Path $isoDir, $mountDir, $tmpDir -Force | Out-Null

    Step "ISO 복사: $IsoPath"
    $disk = Mount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path -PassThru
    try {
        $letter = ($disk | Get-Volume).DriveLetter
        & robocopy.exe "$($letter):\" $isoDir /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "ISO 복사 실패 (robocopy $LASTEXITCODE)" }
    } finally {
        Dismount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path | Out-Null
    }
    Get-ChildItem $isoDir -Recurse -File | ForEach-Object { $_.IsReadOnly = $false }

    $chromeMsi = Join-Path $tmpDir 'chrome.msi'
    if ($cfg.IncludeChrome) {
        Step 'Chrome 기업용 설치 파일 다운로드 (Google 공식)'
        Invoke-WebRequest -UseBasicParsing -Uri $ChromeMsiUrl -OutFile $chromeMsi
        $sig = Get-AuthenticodeSignature $chromeMsi
        if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'Google') {
            throw "Chrome 설치 파일 서명 확인 실패: $($sig.Status) $($sig.SignerCertificate.Subject)"
        }
        Info ("서명 확인: {0}" -f $sig.SignerCertificate.Subject)
    }

    # ========================================================== 3. Pro 이미지 추출
    Step 'Pro 에디션 찾기'
    $srcWim = Join-Path $isoDir 'sources\install.wim'
    $srcEsd = Join-Path $isoDir 'sources\install.esd'
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

    $workWim = Join-Path $tmpDir 'pro.wim'
    Export-WindowsImage -SourceImagePath $src -SourceIndex $pro.ImageIndex `
        -DestinationImagePath $workWim -CompressionType max -CheckIntegrity | Out-Null

    # ========================================================== 4. 마운트
    Step '이미지 마운트'
    Mount-WindowsImage -ImagePath $workWim -Index 1 -Path $mountDir | Out-Null
    $mounted = $true

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
        foreach ($t in $tweaks) {
            Set-RegValue -Path (HivePath $t.Hive $t.Path) -Name $t.Name -Value $t.Value -Type $t.Type
        }
        Info "값 $($tweaks.Count)개 적용"
        foreach ($k in $script:OfflineRegDeleteKeys) {
            $p = HivePath $k.Hive $k.Path
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force; Info "- 키 삭제: $($k.Path)" }
        }
        foreach ($v in $script:OfflineRegDeleteValues) {
            if ($v.Profile -and -not $cfg[$v.Profile]) { continue }
            $p = HivePath $v.Hive $v.Path
            if (Get-ItemProperty -LiteralPath $p -Name $v.Name -ErrorAction SilentlyContinue) {
                Remove-ItemProperty -LiteralPath $p -Name $v.Name -Force; Info "- 값 삭제: $($v.Path)\$($v.Name)"
            }
        }
        # 맥 스타일 포인터 값은 여기서 넣지 않는다: 첫 로그인 마법사에서 고르고,
        # '라이트 윈도우' 로 되돌릴 때 원래 Windows 값을 복원할 수 있어야 하기 때문.
    } finally {
        Dismount-Hives
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
    $cfg | ConvertTo-Json -Depth 5 | Out-File (Join-Path $lw 'profile.json') -Encoding utf8
    @{ RemoveEdge = $cfg.RemoveEdge; EdgeRedirect = $cfg.RemoveEdge } | ConvertTo-Json |
        Out-File (Join-Path $lw 'machine.json') -Encoding utf8

    # LiteWin 자체 프로그램 컴파일 (.NET Framework 내장 컴파일러, 외부 도구 불필요)
    #   LiteWinEdgeRedirect.exe : Edge 전용 링크 → Chrome (상주 안 함)
    #   LiteWinCaption.exe      : 모든 창에 맥식 창 버튼 (맥 UI 모드에서만 실행)
    foreach ($tool in @(
        @{ Src = 'shell\EdgeRedirect.cs';   Out = 'LiteWinEdgeRedirect.exe'; Refs = @() }
        @{ Src = 'shell\LiteWinCaption.cs'; Out = 'LiteWinCaption.exe';      Refs = @('System.Windows.Forms', 'System.Drawing') }
    )) {
        try {
            $tArgs = @{
                TypeDefinition = (Get-Content (Join-Path $RepoRoot $tool.Src) -Raw -Encoding UTF8)
                OutputAssembly = (Join-Path $lw "bin\$($tool.Out)")
                OutputType     = 'WindowsApplication'
                IgnoreWarnings = $true
            }
            if ($tool.Refs.Count) { $tArgs.ReferencedAssemblies = $tool.Refs }
            Add-Type @tArgs
            Info "$($tool.Out) 컴파일"
        } catch { Warn "$($tool.Out) 컴파일 실패 — 이 기능 없이 진행: $($_.Exception.Message)" }
    }

    # 미리 넣는 프로그램 (MPC-BE, ImageGlass, RetroBar, Open-Shell, AutoHotkey)
    Step '내장 프로그램 설치 파일 받기 (winget, 해시 검증)'
    $payloadList = @(Save-WingetPayloads -Dest (Join-Path $lw 'payload'))
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
        Step '기본 앱: Chrome (DISM 기본 앱 연결)'
        & dism.exe /English /Image:$mountDir "/Import-DefaultAppAssociations:$(Join-Path $RepoRoot 'unattend\DefaultAppAssociations.xml')" | Out-Null
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
    $lnk.TargetPath  = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $lnk.Arguments   = '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\LiteWin\app\LiteWinSettings.ps1"'
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
    Dismount-WindowsImage -Path $mountDir -Save | Out-Null
    $mounted = $false

    Step '최대 압축으로 다시 내보내기'
    Remove-Item $srcWim, $srcEsd -Force -ErrorAction SilentlyContinue
    Export-WindowsImage -SourceImagePath $workWim -SourceIndex 1 -DestinationImagePath $srcWim `
        -CompressionType max -CheckIntegrity | Out-Null
    Remove-Item $workWim -Force
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
        if (-not $KeepWorkDir) { Remove-Item $WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Step ("끝 (소요 {0:hh\:mm\:ss})" -f $sw.Elapsed)
}
catch {
    Write-Host "`n오류: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor DarkGray
    throw
}
finally {
    if ($hives.Count) { Dismount-Hives }
    if ($mounted) {
        Warn '오류로 중단 — 마운트된 이미지를 변경 없이 해제합니다'
        Dismount-WindowsImage -Path $mountDir -Discard -ErrorAction SilentlyContinue | Out-Null
    }
}
