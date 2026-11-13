<#
    Edge 브라우저 제거 (WebView2 런타임은 유지) + microsoft-edge: 링크를 Chrome 으로 넘기기
    SYSTEM 또는 관리자 권한에서 실행.

    한국 등 EU 밖 지역에는 공식 "제거" 버튼이 없어서, Edge 자체 설치 프로그램의 제거 명령을
    허용 플래그와 함께 실행한다. Microsoft 지원 방식은 아니지만 Edge 업데이트 구성요소와
    WebView2 는 그대로 두므로 WebView2 를 쓰는 앱(게임 런처, Discord, 위젯 등)은 영향이 없다.
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

$script:EdgeStableGuid = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
$script:WebView2Guid   = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'

function Get-EdgeSetupExe {
    foreach ($base in "${env:ProgramFiles(x86)}\Microsoft\Edge\Application", "$env:ProgramFiles\Microsoft\Edge\Application") {
        $s = Get-ChildItem "$base\*\Installer\setup.exe" -ErrorAction SilentlyContinue |
             Sort-Object FullName -Descending | Select-Object -First 1
        if ($s) { return $s.FullName }
    }
    return $null
}

function Test-EdgeInstalled {
    [bool](Get-EdgeSetupExe) -or
    (Test-Path "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe") -or
    (Test-Path "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe")
}

function Test-WebView2Installed {
    foreach ($k in "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$script:WebView2Guid",
                   "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$script:WebView2Guid") {
        $pv = (Get-ItemProperty $k -Name pv -ErrorAction SilentlyContinue).pv
        if ($pv -and $pv -ne '0.0.0.0') { return $true }
    }
    return $false
}

function Set-EdgeBlockPolicy {
    <# Edge 브라우저 재설치 금지, WebView2 업데이트는 허용 #>
    $p = 'HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate'
    Set-RegValue $p "Install$script:EdgeStableGuid" 0
    Set-RegValue $p 'CreateDesktopShortcutDefault' 0
    Set-RegValue 'HKLM:\SOFTWARE\Microsoft\EdgeUpdate' 'DoNotUpdateToEdgeWithChromium' 1
    # WebView2 는 명시적으로 허용(1) — 보안 업데이트 유지
    Set-RegValue $p "Install$script:WebView2Guid" 1
    Set-RegValue $p "Update$script:WebView2Guid" 1
}

function Remove-EdgeShortcuts {
    $paths = @(
        "$env:PUBLIC\Desktop\Microsoft Edge.lnk"
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"
    )
    $paths += Get-ChildItem 'C:\Users\*\Desktop\Microsoft Edge.lnk' -ErrorAction SilentlyContinue | ForEach-Object FullName
    $paths += Get-ChildItem 'C:\Users\*\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\Microsoft Edge.lnk' -ErrorAction SilentlyContinue | ForEach-Object FullName
    $paths += Get-ChildItem 'C:\Users\*\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk' -ErrorAction SilentlyContinue | ForEach-Object FullName
    foreach ($p in $paths) { if ($p -and (Test-Path $p)) { Remove-Item $p -Force -ErrorAction SilentlyContinue } }
    if (-not (Test-EdgeInstalled)) { Remove-EdgeAssociations }
}

function Remove-EdgeAssociations {
    <# Edge 가 없는데 남아 있는 파일 연결 흔적 정리 → '연결 프로그램' 목록에 Edge 가 나오지 않게 #>
    $c = 'HKLM:\SOFTWARE\Classes'
    foreach ($k in "$c\MSEdgeHTM", "$c\MSEdgePDF", "$c\MSEdgeMHT", "$c\Applications\msedge.exe",
                   'HKLM:\SOFTWARE\Clients\StartMenuInternet\Microsoft Edge', 'HKLM:\SOFTWARE\WOW6432Node\Clients\StartMenuInternet\Microsoft Edge') {
        if (Test-Path $k) { Remove-Item $k -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Remove-ItemProperty 'HKLM:\SOFTWARE\RegisteredApplications' -Name 'Microsoft Edge' -ErrorAction SilentlyContinue
    foreach ($ext in '.htm', '.html', '.shtml', '.xht', '.xhtml', '.xml', '.pdf', '.svg', '.mht', '.mhtml', '.webp', '.url') {
        foreach ($owp in "$c\$ext\OpenWithProgids", "HKCU:\Software\Classes\$ext\OpenWithProgids") {
            $item = Get-Item $owp -ErrorAction SilentlyContinue
            if (-not $item) { continue }
            foreach ($n in $item.GetValueNames()) { if ($n -like 'MSEdge*') { Remove-ItemProperty $owp -Name $n -ErrorAction SilentlyContinue } }
        }
    }
}

function Remove-EdgeBrowser {
    <# .SYNOPSIS Edge 브라우저만 제거. 반환: $true = 제거됨/이미 없음 #>
    param([switch]$Quiet)

    Set-EdgeBlockPolicy
    if (-not (Test-EdgeInstalled)) {
        if (-not $Quiet) { Write-LWLog 'Edge 브라우저가 이미 없습니다.' }
        Remove-EdgeShortcuts
        return $true
    }

    # 제거 허용 플래그 (EU 밖 지역에서 setup.exe --uninstall 을 막는 검사 해제)
    foreach ($k in 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev', 'HKLM:\SOFTWARE\Microsoft\EdgeUpdateDev') {
        Set-RegValue $k 'AllowUninstall' 1
    }

    Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    $setup = Get-EdgeSetupExe
    if ($setup) {
        Write-LWLog "Edge 제거 실행: $setup"
        $p = Start-Process -FilePath $setup -ArgumentList '--uninstall', '--system-level', '--verbose-logging', '--force-uninstall' `
                           -Wait -PassThru -WindowStyle Hidden
        Write-LWLog "Edge setup 종료 코드: $($p.ExitCode)"
    }

    # Store 형태 Edge 패키지(있다면)
    Get-AppxPackage -AllUsers -Name 'Microsoft.MicrosoftEdge.Stable' -ErrorAction SilentlyContinue |
        Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -eq 'Microsoft.MicrosoftEdge.Stable' |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null

    Remove-EdgeShortcuts

    # 빈 Edge\Application 폴더 정리 (EdgeWebView, EdgeUpdate, EdgeCore 는 건드리지 않음)
    foreach ($d in "${env:ProgramFiles(x86)}\Microsoft\Edge", "$env:ProgramFiles\Microsoft\Edge") {
        if ((Test-Path $d) -and -not (Get-ChildItem $d -Recurse -File -Filter msedge.exe -ErrorAction SilentlyContinue)) {
            Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $removed = -not (Test-EdgeInstalled)
    if ($removed) { Write-LWLog 'Edge 브라우저 제거 완료' } else { Write-LWLog 'Edge 제거 실패 (다음 부팅 때 감시 작업이 다시 시도)' WARN }
    if (-not (Test-WebView2Installed)) { Write-LWLog 'WebView2 런타임이 없습니다 — 첫 로그인 후 winget 으로 설치합니다' WARN }
    return $removed
}

function Register-EdgeRedirect {
    <#
        .SYNOPSIS microsoft-edge: 링크를 LiteWinEdgeRedirect.exe(→ Chrome) 로 연결
        Edge 가 지워진 뒤 실행해야 한다(Edge 가 있으면 Windows 가 Edge 로 고정해서 연다).
    #>
    param([string]$ExePath = (Join-Path $script:LWRoot 'bin\LiteWinEdgeRedirect.exe'))
    if (-not (Test-Path $ExePath)) { Write-LWLog "리다이렉트 프로그램 없음: $ExePath" WARN; return }
    $base = 'HKLM:\SOFTWARE\Classes\microsoft-edge'
    Set-RegValue $base '(default)' 'URL:microsoft-edge' String
    Set-RegValue $base 'URL Protocol' '' String
    Set-RegValue "$base\DefaultIcon" '(default)' "`"$ExePath`",0" String
    Set-RegValue "$base\shell\open\command" '(default)' "`"$ExePath`" `"%1`"" String
    Write-LWLog 'microsoft-edge: 링크 → Chrome 리다이렉트 등록'
}

function Unregister-EdgeRedirect {
    Remove-Item 'HKLM:\SOFTWARE\Classes\microsoft-edge' -Recurse -Force -ErrorAction SilentlyContinue
}

function Register-EdgeGuardTask {
    <# 기능 업데이트 등으로 Edge 가 다시 깔리면 부팅 때 자동으로 다시 제거 #>
    $script = Join-Path $script:LWRoot 'app\EdgeGuard.ps1'
    $action    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$script`""
    $triggers  = @(New-ScheduledTaskTrigger -AtStartup)
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
    Register-ScheduledTask -TaskName 'LiteWin Edge Guard' -TaskPath '\LiteWin\' -Action $action -Trigger $triggers `
        -Principal $principal -Settings $settings -Force | Out-Null
}

function Unregister-EdgeGuardTask {
    Unregister-ScheduledTask -TaskName 'LiteWin Edge Guard' -TaskPath '\LiteWin\' -Confirm:$false -ErrorAction SilentlyContinue
}
