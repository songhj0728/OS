<#
.SYNOPSIS
    이미 LiteWin 이 설치된 PC(VM) 안에서 실행: 저장소의 최신 스크립트/프로그램만 C:\ProgramData\LiteWin 에 반영한다.
    ISO 를 다시 만들고 재설치하지 않아도 설정 앱·셸·맥 단축키·구성요소 관리자 수정분을 바로 확인할 수 있다.

.DESCRIPTION
    VMware: VM 설정 > 옵션 > 공유 폴더 에 이 저장소 폴더를 추가(읽기 전용 권장)한 뒤, VM 안의 관리자 PowerShell 에서
        powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\OS\tools\Update-LiteWinFromRepo.ps1"
    (VirtualBox: \\VBOXSVR\OS\..., Hyper-V: 폴더를 복사해 넣고 실행)

    반영 대상: lib, app, apps, macstyle + shell\*.cs 를 컴파일한 exe (bin)
    반영되지 않는 것: 이미지 단계 변경(지우는 앱 목록, 레지스트리 정책, Edge 제거, autounattend) → ISO 재빌드 필요 (-Fast)

.PARAMETER Source     저장소 폴더 (기본: 이 스크립트의 상위 폴더)
.PARAMETER RunSetup   setup\PostInstall.ps1 도 다시 실행 (설치 마지막 단계 스크립트를 고쳤을 때)
.PARAMETER OpenSettings 끝나면 LiteWin 설정을 연다
#>
[CmdletBinding()]
param(
    [string]$Source = (Split-Path -Parent $PSScriptRoot),
    [switch]$RunSetup,
    [switch]$OpenSettings
)
$ErrorActionPreference = 'Stop'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { throw '관리자 권한 PowerShell 에서 실행하세요.' }

$dest = Join-Path $env:ProgramData 'LiteWin'
if (-not (Test-Path $dest)) { throw "LiteWin 이 설치된 PC 가 아닙니다 ($dest 없음)." }
$sw = [Diagnostics.Stopwatch]::StartNew()

# 실행 중인 LiteWin 프로그램 종료 (exe 교체를 위해)
foreach ($n in 'LiteWinCaption', 'LiteWinSettings') { Get-Process $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue }

foreach ($d in 'lib', 'app', 'apps', 'macstyle') {
    & robocopy.exe (Join-Path $Source $d) (Join-Path $dest $d) /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "복사 실패: $d (robocopy $LASTEXITCODE)" }
    Write-Host "  동기화: $d"
}

# 네트워크 공유에서 직접 컴파일하면 느리고 잠길 수 있어 로컬 임시 폴더로 가져와 별도 프로세스에서 컴파일
$tmp = Join-Path $env:TEMP 'LiteWin-sync'
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$tmp\build", "$tmp\shell", "$tmp\out" -Force | Out-Null
Copy-Item (Join-Path $Source 'build\Compile-LiteWinTools.ps1') "$tmp\build" -Force
Copy-Item (Join-Path $Source 'shell\*.cs') "$tmp\shell" -Force
& "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass `
    -File "$tmp\build\Compile-LiteWinTools.ps1" -OutDir "$tmp\out" | Out-Host
New-Item -ItemType Directory -Path "$dest\bin" -Force | Out-Null
Get-ChildItem "$tmp\out" -Filter *.exe | ForEach-Object { Copy-Item $_.FullName "$dest\bin" -Force; Write-Host "  교체: bin\$($_.Name)" }

if ($RunSetup) {
    Write-Host '  setup\PostInstall.ps1 다시 실행'
    Copy-Item (Join-Path $Source 'setup\*') "$env:WINDIR\Setup\Scripts" -Force
    & "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass `
        -File "$env:WINDIR\Setup\Scripts\PostInstall.ps1" | Out-Host
}

# 구성요소 관리 작업 / 셸 다시 적용 (현재 모드 그대로)
. (Join-Path $dest 'lib\LiteWin.Components.ps1')
. (Join-Path $dest 'lib\LiteWin.Shell.ps1')
try { Register-LWComponentTask } catch { Write-Host "  ! 구성요소 작업 등록 실패: $_" -ForegroundColor Yellow }
Start-LWShell -Apply
Get-ScheduledTask -TaskPath '\LiteWin\' -TaskName 'LiteWin MacKeys*' -ErrorAction SilentlyContinue | Where-Object State -ne 'Disabled' | ForEach-Object {
    Get-CimInstance Win32_Process -Filter "Name LIKE 'AutoHotkey%'" | Where-Object { $_.CommandLine -like '*MacKeys.ahk*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Start-ScheduledTask -TaskPath $_.TaskPath -TaskName $_.TaskName
    Write-Host '  맥 단축키 다시 시작'
}

Write-Host ("완료 ({0:N0}초)" -f $sw.Elapsed.TotalSeconds) -ForegroundColor Cyan
if ($OpenSettings) { Start-Process (Join-Path $dest 'bin\LiteWinSettings.exe') }
