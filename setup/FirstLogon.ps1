<#
    autounattend.xml 의 FirstLogonCommands 로 "처음 만든 사용자"가 첫 로그인할 때 1회 실행 (관리자 권한).
    - 맥 스타일(키보드/마우스/트랙패드) 적용
    - 인터넷이 아직 없거나 winget 준비 전이면, 바탕화면에 "맥 스타일 설치" 바로가기를 남긴다.
#>
$ErrorActionPreference = 'Continue'
$root = Join-Path $env:ProgramData 'LiteWin'
$log  = Join-Path $root 'logs\FirstLogon.log'
New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
Start-Transcript -Path $log -Append | Out-Null

try {
    $p = Get-Content (Join-Path $root 'profile.json') -Raw -Encoding UTF8 | ConvertFrom-Json
} catch { $p = [pscustomobject]@{ MacStyle = $false } }

if ($p.MacStyle) {
    $installer = Join-Path $root 'macstyle\Install-MacStyle.ps1'

    # 첫 로그인 직후엔 winget(App Installer)이 아직 등록 중일 수 있어 최대 약 3분 기다린다.
    for ($i = 0; $i -lt 18 -and -not (Get-Command winget.exe -ErrorAction SilentlyContinue); $i++) {
        Start-Sleep -Seconds 10
    }

    $ok = $false
    try {
        & $installer -ErrorAction Stop
        $ok = $true
    } catch {
        Write-Output "맥 스타일 자동 설치 실패: $_"
    }

    if (-not $ok) {
        # 나중에 사용자가 더블클릭해서 재시도할 수 있게 바로가기 생성
        $desktop = [Environment]::GetFolderPath('Desktop')
        $lnkPath = Join-Path $desktop '맥 스타일 설치.lnk'
        $ws = New-Object -ComObject WScript.Shell
        $lnk = $ws.CreateShortcut($lnkPath)
        $lnk.TargetPath = 'powershell.exe'
        $lnk.Arguments  = "-NoProfile -ExecutionPolicy Bypass -File `"$installer`""
        $lnk.Description = '인터넷 연결 후 실행하세요 (관리자 권한 요청)'
        $lnk.Save()
        # 바로가기를 "관리자 권한으로 실행"으로 표시 (lnk 플래그 바이트 0x15 의 0x20 비트)
        $bytes = [IO.File]::ReadAllBytes($lnkPath); $bytes[0x15] = $bytes[0x15] -bor 0x20
        [IO.File]::WriteAllBytes($lnkPath, $bytes)
    }
}

Stop-Transcript | Out-Null
