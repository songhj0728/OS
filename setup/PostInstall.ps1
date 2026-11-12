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

# 설치 이미지에 남은 임시 파일 정리
Remove-Item "$env:WINDIR\Setup\Scripts\*.log" -ErrorAction SilentlyContinue
Log '완료'
exit 0
