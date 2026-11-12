<#
    SetupComplete.cmd 가 SYSTEM 권한으로 1회 실행. (첫 로그인 전)
    빌드 때 저장한 프로필(C:\ProgramData\LiteWin\profile.json)을 읽어 시스템 전역 설정을 한다.
    어떤 단계가 실패해도 설치는 계속되도록 전부 개별 try/catch.
#>
$ErrorActionPreference = 'Continue'
$root = Join-Path $env:ProgramData 'LiteWin'
$profilePath = Join-Path $root 'profile.json'
function Log($m) { Write-Output ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date), $m) }

if (-not (Test-Path $profilePath)) { Log "profile.json 없음 - 건너뜀"; exit 0 }
$p = Get-Content $profilePath -Raw -Encoding UTF8 | ConvertFrom-Json
Log "프로필: $($p.Name)"

foreach ($svc in @($p.DisableServices)) {
    try { Set-Service -Name $svc -StartupType Disabled -ErrorAction Stop; Log "서비스 사용 안 함: $svc" }
    catch { Log "서비스 건너뜀(없음?): $svc" }
}
foreach ($svc in @($p.ManualServices)) {
    try { Set-Service -Name $svc -StartupType Manual -ErrorAction Stop; Log "서비스 수동: $svc" }
    catch { Log "서비스 건너뜀(없음?): $svc" }
}
if ($p.DisableSearchIndexing) {
    try { Set-Service WSearch -StartupType Disabled; Stop-Service WSearch -Force -ErrorAction SilentlyContinue; Log '검색 색인 끔' } catch { Log "WSearch 실패: $_" }
}
if ($p.DisableSysMain) {
    try { Set-Service SysMain -StartupType Disabled; Stop-Service SysMain -Force -ErrorAction SilentlyContinue; Log 'SysMain 끔' } catch { Log "SysMain 실패: $_" }
}

foreach ($t in @($p.DisableTasks)) {
    $path = ($t.Substring(0, $t.LastIndexOf('\') + 1))
    $name = ($t.Substring($t.LastIndexOf('\') + 1))
    try { Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null; Log "작업 끔: $t" }
    catch { Log "작업 건너뜀(없음?): $t" }
}

if ($p.DisableHibernation) {
    & powercfg.exe /hibernate off; Log '최대 절전 끔 (hiberfil.sys 삭제)'
}

# 예약 저장소(업데이트용 7GB 가량 미리 잡아두는 공간)는 업데이트 안정성을 위해 그대로 둔다.

# ---------------------------------------------------------------- Chrome (기본 브라우저)
$chromeMsi = Join-Path $root 'payload\chrome.msi'
$chromeOk = $false
if (Test-Path $chromeMsi) {
    try {
        $proc = Start-Process msiexec.exe -ArgumentList '/i', "`"$chromeMsi`"", '/qn', '/norestart' -Wait -PassThru
        Log "Chrome 설치 종료 코드: $($proc.ExitCode)"
        $chromeOk = $proc.ExitCode -in 0, 3010
        # 첫 실행 안내/기본 브라우저 묻기/가져오기 화면 생략 (정책이 아니라서 '관리됨' 표시 없음)
        $appDir = "$env:ProgramFiles\Google\Chrome\Application"
        if (Test-Path $appDir) {
            @'
{
  "distribution": {
    "skip_first_run_ui": true,
    "suppress_first_run_default_browser_prompt": true,
    "import_bookmarks": false,
    "import_history": false,
    "import_search_engine": false,
    "make_chrome_default_for_user": false
  },
  "browser": { "check_default_browser": false }
}
'@ | Set-Content (Join-Path $appDir 'initial_preferences') -Encoding ASCII
        }
        Remove-Item $chromeMsi -Force -ErrorAction SilentlyContinue
    } catch { Log "Chrome 설치 실패: $_" }
}

# ---------------------------------------------------------------- 내장 프로그램 (MPC-BE, ImageGlass, RetroBar, Open-Shell, AutoHotkey)
$payloadDir = Join-Path $root 'payload'
$payloadJson = Join-Path $payloadDir 'payloads.json'
if (Test-Path $payloadJson) {
    foreach ($pl in @(Get-Content $payloadJson -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        if (-not $pl -or -not $pl.File) { continue }
        $file = Join-Path $payloadDir $pl.File
        if (-not (Test-Path $file)) { continue }
        try {
            if ($file -like '*.msi') {
                $proc = Start-Process msiexec.exe -ArgumentList "/i `"$file`" $($pl.Args)" -Wait -PassThru
            } elseif ($pl.Args) {
                $proc = Start-Process $file -ArgumentList $pl.Args -Wait -PassThru
            } else {
                $proc = Start-Process $file -Wait -PassThru
            }
            Log "설치: $($pl.Name) 종료 코드 $($proc.ExitCode)"
            if (-not $pl.Keep) { Remove-Item $file -Force -ErrorAction SilentlyContinue }   # EP 는 재설치용으로 보관
        } catch { Log "설치 실패: $($pl.Name) — $_" }
    }
}

# ---------------------------------------------------------------- 기본 앱: 웹=Chrome, 동영상=MPC-BE(HEVC 포함), .heic=ImageGlass
#   설치된 프로그램이 등록한 ProgId 를 직접 찾아 기본 앱 연결 파일을 만들고, 첫 로그인 전에 가져온다(새 사용자에 적용).
function Find-ProgId([string]$ext, [string]$pattern) {
    # 1) RegisteredApplications → Capabilities\FileAssociations
    $reg = Get-ItemProperty 'HKLM:\SOFTWARE\RegisteredApplications' -ErrorAction SilentlyContinue
    if ($reg) {
        foreach ($prop in $reg.PSObject.Properties) {
            if ($prop.Name -like 'PS*' -or "$($prop.Name) $($prop.Value)" -notmatch $pattern) { continue }
            $fa = Get-ItemProperty ("HKLM:\" + $prop.Value + '\FileAssociations') -ErrorAction SilentlyContinue
            if ($fa -and $fa.$ext) { return $fa.$ext }
        }
    }
    # 2) 확장자의 OpenWithProgids
    $owp = Get-Item "HKLM:\SOFTWARE\Classes\$ext\OpenWithProgids" -ErrorAction SilentlyContinue
    if ($owp) { foreach ($n in $owp.GetValueNames()) { if ($n -match $pattern) { return $n } } }
    return $null
}
$assoc = [ordered]@{}
foreach ($e in '.mp4', '.m4v', '.mkv', '.mov', '.avi', '.wmv', '.webm', '.ts', '.m2ts', '.mts', '.hevc', '.h265', '.265', '.flv', '.3gp', '.mpg', '.mpeg') {
    $id = Find-ProgId $e 'mpc'
    if ($id) { $assoc[$e] = @($id, 'MPC-BE') }
}
foreach ($e in '.heic', '.heif', '.avif') {
    $id = Find-ProgId $e 'ImageGlass'
    if ($id) { $assoc[$e] = @($id, 'ImageGlass') }
}
$browser = $null
if (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe") { $browser = @('ChromeHTML', 'Google Chrome') }
try {
    # Windows 기본 연결 파일과 '병합'해서 가져온다 (전체 교체라 일부만 넣으면 다른 기본값이 사라짐)
    . (Join-Path $root 'lib\LiteWin.Assoc.ps1')
    $xmlPath = Join-Path $root 'DefaultAssociations.xml'
    Merge-DefaultAssociations -Source "$env:WINDIR\System32\OEMDefaultAssociations.xml" -Output $xmlPath -Entries $assoc -Browser $browser
    & dism.exe /Online /English "/Import-DefaultAppAssociations:$xmlPath" | Out-Null
    Log "기본 앱 연결 병합: 추가 $($assoc.Count)개 + 브라우저 (dism 코드 $LASTEXITCODE)"
} catch { Log "기본 앱 연결 실패: $_" }

# ---------------------------------------------------------------- Edge 제거 (WebView2 유지) + 링크 리다이렉트
# Edge 는 이미 설치 이미지 단계에서 빠져 있다. 여기서는 남은 흔적 정리 + 재설치 감시만.
if ($p.RemoveEdge) {
    try {
        . (Join-Path $root 'lib\LiteWin.Edge.ps1')
        [void](Remove-EdgeBrowser)
        Register-EdgeRedirect
        Register-EdgeGuardTask
    } catch { Log "Edge 처리 실패: $_" }
    if (-not (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe")) {
        # 브라우저가 하나도 없는 상태 → 첫 로그인 후 인터넷으로 Chrome 설치 (Apply-LiteWin.ps1)
        Log 'Chrome 설치 실패 — 첫 로그인 후 winget 으로 다시 설치합니다'
    }
}

# ---------------------------------------------------------------- 구성요소 관리자 (Windows Update 와 함께 조용히 갱신)
try {
    . (Join-Path $root 'lib\LiteWin.Components.ps1')
    Hide-LWComponentsFromApps
    Register-LWComponentTask
    Log '구성요소 관리 작업 등록 (부팅 / Windows Update 직후 / 매일)'
} catch { Log "구성요소 관리 작업 등록 실패: $_" }

# 설치 이미지에 남은 임시 파일 정리
Remove-Item "$env:WINDIR\Setup\Scripts\*.log" -ErrorAction SilentlyContinue
Log '완료'
exit 0
