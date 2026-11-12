<#
    autounattend.xml 의 FirstLogonCommands 로 "처음 만든 사용자"가 첫 로그인할 때 1회 실행 (관리자 권한).
    LiteWin 설정 마법사(-FirstRun)를 띄운다. 마법사는 바탕화면이 뜬 뒤 따로 실행되므로 로그인을 막지 않는다.
    - 모드(라이트/맥 입력/맥 UI), 사진·동영상 추가 형식, 게임 플랫폼을 고르거나 [앱 설치 건너뛰기]
    - 나중에 다시: 시작 메뉴 > LiteWin 설정
#>
$ErrorActionPreference = 'Continue'
$root = Join-Path $env:ProgramData 'LiteWin'
$log  = Join-Path $root 'logs\FirstLogon.log'
New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
Start-Transcript -Path $log -Append | Out-Null

$exe = Join-Path $root 'bin\LiteWinSettings.exe'
$settings = Join-Path $root 'app\LiteWinSettings.ps1'
if (Test-Path $exe) {
    Start-Process $exe -ArgumentList '-FirstRun'     # 콘솔 창 없이 바로 열림
    Write-Output 'LiteWin 설정 마법사 실행 (exe)'
} elseif (Test-Path $settings) {
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden',
        '-File', "`"$settings`"", '-FirstRun')
    Write-Output 'LiteWin 설정 마법사 실행'
} else {
    Write-Output "설정 앱 없음: $settings"
}

Stop-Transcript | Out-Null
