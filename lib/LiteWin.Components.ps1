<#
    LiteWin 구성요소 관리자 — ExplorerPatcher 등 셸 구성요소를 Windows Update 와 맞물려 조용히 관리한다.
      * 설치/업데이트: 공식 배포처(GitHub 릴리스 / winget)에서만, 해시 검증, 배포 후 N일(기본 7일) 지난 버전만
      * 기능 업데이트(예: 24H2→25H2)가 받아지거나 업그레이드 차단이 감지되면 ExplorerPatcher 를 잠시 제거하고,
        업그레이드가 끝나면(빌드 번호가 바뀌면) 다시 설치한다
      * 설정 > 앱 목록에서 셸 구성요소를 숨긴다 (사용자가 신경 쓸 필요 없게)
    SYSTEM 예약 작업(app\Update-LiteWinComponents.ps1)에서 실행된다.
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:ComponentsFile = Join-Path $script:LWRoot 'components.json'
$script:EPRepo = 'valinet/ExplorerPatcher'
$script:EPAsset = 'ep_setup.exe'
# winget 으로 관리하는 셸 구성요소 (winget 저장소는 검토 후 등록 + 해시 검증)
$script:WingetComponents = @('dremin.RetroBar', 'Open-Shell.Open-Shell-Menu', 'MPC-BE.MPC-BE', 'DuongDieuPhap.ImageGlass')
# 설정 > 앱 에서 숨길 셸 구성요소 (사용자용 앱인 MPC-BE/ImageGlass/Chrome 은 숨기지 않음)
$script:HiddenComponents = @('ExplorerPatcher*', 'RetroBar*', 'Open-Shell*', 'AutoHotkey*')   # AutoHotkey: 예전 빌드에서 설치된 경우 숨김

function Get-LWComponentState {
    $d = [ordered]@{ AutoUpdate = $true; DelayDays = 7; EpSuspended = $false; EpSuspendedBuild = ''; EpSuspendedAt = ''; PendingEpUpdate = ''; History = @() }
    if (Test-Path $script:ComponentsFile) {
        try {
            $j = Get-Content $script:ComponentsFile -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $j.PSObject.Properties) { $d[$p.Name] = $p.Value }
        } catch { }
    }
    return [pscustomobject]$d
}

function Save-LWComponentState($State) {
    $h = @($State.History)
    if ($h.Count -gt 50) { $State.History = $h[-50..-1] }
    $State | ConvertTo-Json -Depth 5 | Set-Content $script:ComponentsFile -Encoding UTF8
}

function Add-LWHistory($State, [string]$Text) {
    $State.History = @($State.History) + ('{0:yyyy-MM-dd HH:mm} {1}' -f (Get-Date), $Text)
    Write-LWLog $Text -File 'Components.log'
}

function Get-OSBuild {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    "$($cv.CurrentBuild).$($cv.UBR)"
}

# ------------------------------------------------------------------ 설치 목록(앱 목록) 항목
function Get-UninstallEntries([string]$NameLike) {
    foreach ($root in 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
        Get-ChildItem $root -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($p -and $p.DisplayName -like $NameLike) { $p }
        }
    }
}

function Hide-LWComponentsFromApps {
    foreach ($n in $script:HiddenComponents) {
        foreach ($e in @(Get-UninstallEntries $n)) { Set-RegValue $e.PSPath 'SystemComponent' 1 }
    }
}

# ------------------------------------------------------------------ ExplorerPatcher
function Get-EPInstalled {
    $e = @(Get-UninstallEntries 'ExplorerPatcher*') | Select-Object -First 1
    if (-not $e) { return $null }
    $setup = $null
    if ($e.UninstallString -match '"([^"]+ep_setup\.exe)"') { $setup = $Matches[1] }
    elseif ($e.UninstallString -match '([A-Za-z]:\\[^"]+ep_setup\.exe)') { $setup = $Matches[1] }
    if (-not $setup) { $setup = Join-Path $env:ProgramFiles 'ExplorerPatcher\ep_setup.exe' }
    [pscustomobject]@{ Version = (ConvertTo-EPVersion $e.DisplayVersion); RawVersion = $e.DisplayVersion; Setup = $setup }
}

function ConvertTo-EPVersion([string]$s) {
    # 태그 예: 22621.3880.66.6_92fce8c → 22621.3880.66.6
    $v = $null
    if ($s -and [version]::TryParse(($s -split '[_\s-]')[0], [ref]$v)) { return $v }
    return [version]'0.0'
}

function Get-GitHubRelease {
    <# 최신 정식 릴리스 + 지정 자산. 배포 후 DelayDays 가 지나지 않았으면 그 이전 릴리스 중 가장 최신 #>
    param([string]$Repo, [string]$Asset, [int]$DelayDays = 7, [string]$AssetPattern)
    $h = @{ 'User-Agent' = 'LiteWin-Components'; 'Accept' = 'application/vnd.github+json' }
    $rels = Invoke-RestMethod -UseBasicParsing -Headers $h -Uri "https://api.github.com/repos/$Repo/releases?per_page=15" -TimeoutSec 30
    foreach ($r in $rels) {
        if ($r.draft -or $r.prerelease) { continue }
        if (([DateTime]$r.published_at).AddDays($DelayDays) -gt (Get-Date)) { continue }
        $a = if ($AssetPattern) { $r.assets | Where-Object { $_.name -match $AssetPattern } | Select-Object -First 1 }
             else { $r.assets | Where-Object name -eq $Asset | Select-Object -First 1 }
        if (-not $a) { continue }
        return [pscustomobject]@{
            Tag = $r.tag_name; Version = (ConvertTo-EPVersion $r.tag_name); Published = [DateTime]$r.published_at; AssetName = $a.name
            Url = $a.browser_download_url; Sha256 = if ($a.digest -match '^sha256:([0-9a-fA-F]{64})$') { $Matches[1].ToUpper() } else { $null }
        }
    }
    return $null
}

function Save-VerifiedAsset {
    <# 다운로드 후 GitHub 가 제공하는 SHA-256 과 비교. 해시 정보가 없으면 $AllowUnverified 일 때만 허용 #>
    param($Release, [string]$OutFile, [switch]$AllowUnverified)
    Invoke-WebRequest -UseBasicParsing -Uri $Release.Url -OutFile $OutFile -TimeoutSec 300
    $hash = (Get-FileHash $OutFile -Algorithm SHA256).Hash
    if ($Release.Sha256) {
        if ($hash -ne $Release.Sha256) { Remove-Item $OutFile -Force; throw "해시 불일치 ($($Release.Tag))" }
    } elseif (-not $AllowUnverified) {
        Remove-Item $OutFile -Force; throw "배포처가 해시를 제공하지 않아 설치하지 않음 ($($Release.Tag))"
    }
    return $hash
}

function Install-EP {
    param([Parameter(Mandatory)][string]$Setup, [switch]$Update)
    $args2 = if ($Update) { '/update_silent' } else { '' }
    $p = if ($args2) { Start-Process $Setup -ArgumentList $args2 -Wait -PassThru } else { Start-Process $Setup -Wait -PassThru }
    Hide-LWComponentsFromApps
    return $p.ExitCode
}

function Uninstall-EP {
    $ep = Get-EPInstalled
    if (-not $ep -or -not (Test-Path $ep.Setup)) { return $false }
    # 제거 후 재설치를 위해 설치 파일을 따로 보관
    $keep = Join-Path $script:LWRoot 'payload\ep_setup.exe'
    New-Item -ItemType Directory -Path (Split-Path $keep) -Force | Out-Null
    Copy-Item $ep.Setup $keep -Force -ErrorAction SilentlyContinue
    Start-Process $ep.Setup -ArgumentList '/uninstall_silent' -Wait | Out-Null
    return -not (Get-EPInstalled)
}

# ------------------------------------------------------------------ 기능 업데이트 감지
function Test-FeatureUpdateStaged {
    <# 기능 업데이트가 받아졌거나 설치 준비 중인지 #>
    if (Test-Path "$env:SystemDrive\`$WINDOWS.~BT\Sources\SetupHost.exe") { return $true }
    try {
        $session = New-Object -ComObject Microsoft.Update.Session
        $result = $session.CreateUpdateSearcher().Search("IsInstalled=0 and IsHidden=0")
        foreach ($u in $result.Updates) {
            if ($u.Title -match '(Feature update|기능 업데이트|Windows 11, version \d\dH\d)' -and $u.IsDownloaded) { return $true }
        }
    } catch { }
    return $false
}

function Test-UpgradeBlockIndicated {
    <# Windows 호환성 평가가 업그레이드를 막고 있다는 표시가 있는지 #>
    $root = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\TargetVersionUpgradeExperienceIndicators'
    foreach ($k in Get-ChildItem $root -ErrorAction SilentlyContinue) {
        $p = Get-ItemProperty $k.PSPath -ErrorAction SilentlyContinue
        foreach ($n in 'RedReason', 'GatedBlockId', 'GatedBlockReason') {
            $v = "$($p.$n)"
            if ($v -and $v -notmatch '^(None|0|)$') { return $true }
        }
    }
    return $false
}

function Invoke-UpgradeRescan {
    # 호환성 평가 + Windows Update 검색을 다시 돌려 차단이 풀렸는지 반영
    Start-Process "$env:WINDIR\System32\CompatTelRunner.exe" -ArgumentList '-m:appraiser.dll -f:DoScheduledTelemetryRun' -WindowStyle Hidden -ErrorAction SilentlyContinue
    Start-Process "$env:WINDIR\System32\UsoClient.exe" -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------------ 한 번 실행 (예약 작업 본체)
function Invoke-LWComponentMaintenance {
    param([switch]$AtBoot, [switch]$Force)
    $st = Get-LWComponentState
    $build = Get-OSBuild
    $ep = Get-EPInstalled
    $userActive = [bool](Get-Process explorer -ErrorAction SilentlyContinue)

    # 1) 기능 업데이트 보호
    if ($ep -and -not $st.EpSuspended) {
        $staged = Test-FeatureUpdateStaged
        $blocked = Test-UpgradeBlockIndicated
        if ($staged -or $blocked) {
            if (Uninstall-EP) {
                $st.EpSuspended = $true; $st.EpSuspendedBuild = $build; $st.EpSuspendedAt = (Get-Date).ToString('s')
                Add-LWHistory $st ("기능 업데이트 보호: ExplorerPatcher 임시 제거 (" + $(if ($staged) { '업데이트 준비됨' } else { '업그레이드 차단 표시' }) + ") — 작업표시줄은 RetroBar 로 대체")
                if ($blocked) { Invoke-UpgradeRescan }
            }
            Save-LWComponentState $st
            return
        }
    }
    if ($st.EpSuspended) {
        $age = (Get-Date) - [DateTime]$st.EpSuspendedAt
        $upgraded = $build.Split('.')[0] -ne "$($st.EpSuspendedBuild)".Split('.')[0]
        if ($upgraded -or ($age.TotalDays -ge 3 -and -not (Test-FeatureUpdateStaged) -and -not (Test-UpgradeBlockIndicated))) {
            $setup = Join-Path $script:LWRoot 'payload\ep_setup.exe'
            try {
                # 업그레이드 뒤에는 새 빌드를 지원하는 최신 버전이 필요할 수 있으므로 먼저 최신판을 받아본다
                $rel = Get-GitHubRelease -Repo $script:EPRepo -Asset $script:EPAsset -DelayDays ([int]$st.DelayDays)
                if ($rel) { [void](Save-VerifiedAsset -Release $rel -OutFile $setup) }
            } catch { Write-LWLog "EP 최신판 받기 실패, 보관본 사용: $_" WARN -File 'Components.log' }
            if (Test-Path $setup) {
                [void](Install-EP -Setup $setup)
                $st.EpSuspended = $false
                Add-LWHistory $st "ExplorerPatcher 다시 설치 (빌드 $build)"
            }
        }
        Save-LWComponentState $st
        return
    }

    if (-not $st.AutoUpdate -and -not $Force) { Hide-LWComponentsFromApps; return }

    # 2) ExplorerPatcher 업데이트 (사용 중이면 다음 부팅 때 적용)
    if ($ep) {
        try {
            $rel = Get-GitHubRelease -Repo $script:EPRepo -Asset $script:EPAsset -DelayDays ([int]$st.DelayDays)
            if ($rel -and $rel.Version -gt $ep.Version) {
                if ($userActive -and -not $AtBoot) {
                    if ($st.PendingEpUpdate -ne $rel.Tag) { $st.PendingEpUpdate = $rel.Tag; Add-LWHistory $st "ExplorerPatcher $($rel.Tag) — 다음 부팅 때 설치" }
                } else {
                    $file = Join-Path $env:TEMP 'ep_setup.exe'
                    [void](Save-VerifiedAsset -Release $rel -OutFile $file)
                    $code = Install-EP -Setup $file -Update
                    Copy-Item $file (Join-Path $script:LWRoot 'payload\ep_setup.exe') -Force -ErrorAction SilentlyContinue
                    $st.PendingEpUpdate = ''
                    Add-LWHistory $st "ExplorerPatcher $($ep.RawVersion) → $($rel.Tag) (코드 $code)"
                }
            }
        } catch { Write-LWLog "EP 업데이트 확인 실패: $_" WARN -File 'Components.log' }
    }

    # 3) winget 구성요소 업데이트
    $winget = Get-WingetPath
    if ($winget) {
        foreach ($id in $script:WingetComponents) {
            $out = & $winget upgrade --id $id --exact --source winget --silent --accept-package-agreements `
                       --accept-source-agreements --disable-interactivity 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $out -match '(Successfully installed|설치했습니다)') { Add-LWHistory $st "$id 업데이트" }
        }
    }

    Hide-LWComponentsFromApps
    Save-LWComponentState $st
}

function Register-LWComponentTask {
    <# 부팅 시 + Windows Update 설치 직후(이벤트 19) + 매일 — SYSTEM 으로 실행 #>
    $script = Join-Path $script:LWRoot 'app\Update-LiteWinComponents.ps1'
    $ps = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
    $xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo><Description>LiteWin 구성요소 관리 (ExplorerPatcher 등). Windows Update 와 함께 조용히 업데이트하고 기능 업데이트 시 보호.</Description></RegistrationInfo>
  <Triggers>
    <BootTrigger><Delay>PT1M</Delay><Enabled>true</Enabled></BootTrigger>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Delay>PT5M</Delay>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="System"&gt;&lt;Select Path="System"&gt;*[System[Provider[@Name='Microsoft-Windows-WindowsUpdateClient'] and (EventID=19 or EventID=43)]]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
    </EventTrigger>
    <CalendarTrigger><StartBoundary>2026-01-01T12:37:00</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger>
  </Triggers>
  <Principals><Principal id="Author"><UserId>S-1-5-18</UserId><RunLevel>HighestAvailable</RunLevel></Principal></Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <ExecutionTimeLimit>PT1H</ExecutionTimeLimit>
    <Hidden>true</Hidden>
  </Settings>
  <Actions Context="Author">
    <Exec><Command>$ps</Command><Arguments>-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$script"</Arguments></Exec>
  </Actions>
</Task>
"@
    Register-ScheduledTask -TaskName 'LiteWin Components' -TaskPath '\LiteWin\' -Xml $xml -Force | Out-Null
}
