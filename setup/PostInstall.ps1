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

# ---------------------------------------------------------------- Edge 제거 (WebView2 유지) + 링크 리다이렉트
if ($p.RemoveEdge) {
    if (-not $chromeOk -and -not (Test-Path "$env:ProgramFiles\Google\Chrome\Application\chrome.exe")) {
        Log 'Chrome 이 설치되지 않아 Edge 제거를 건너뜀 (브라우저가 하나도 없게 되는 것 방지)'
        @{ RemoveEdge = $false; EdgeRedirect = $false } | ConvertTo-Json | Set-Content (Join-Path $root 'machine.json') -Encoding UTF8
    } else {
        try {
            . (Join-Path $root 'lib\LiteWin.Edge.ps1')
            [void](Remove-EdgeBrowser)
            Register-EdgeRedirect
            Register-EdgeGuardTask
        } catch { Log "Edge 처리 실패: $_" }
    }
}

# 설치 이미지에 남은 임시 파일 정리
Remove-Item "$env:WINDIR\Setup\Scripts\*.log" -ErrorAction SilentlyContinue
Log '완료'
exit 0
