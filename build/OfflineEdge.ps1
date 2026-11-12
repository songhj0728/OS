<#
    설치 이미지(오프라인)에서 Edge 브라우저를 뺀다. WebView2 런타임과 EdgeUpdate(WebView2 업데이트용)는 남긴다.
    설치가 끝난 뒤가 아니라 이미지 단계에서 빼므로, 처음부터 Edge 가 없는 상태로 설치된다
    (파일 연결 목록·시작 메뉴·'연결 프로그램'에 Edge 가 남지 않음).
    Build-LiteWin.ps1 이 레지스트리 하이브를 마운트한 상태에서 호출한다.
#>

$script:EdgeStableGuidOffline = '{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}'
$script:WebView2GuidOffline   = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'

function Remove-ProtectedPath([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    # 이미지 안 파일은 TrustedInstaller 소유라 소유권을 가져온 뒤 지운다
    & takeown.exe /F $Path /R /A /D Y 2>&1 | Out-Null
    & icacls.exe $Path /grant '*S-1-5-32-544:F' /T /C /Q 2>&1 | Out-Null
    Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    return -not (Test-Path -LiteralPath $Path)
}

function Remove-EdgeFromImage {
    param(
        [Parameter(Mandatory)][string]$MountDir,
        [Parameter(Mandatory)][scriptblock]$HivePath,      # { param($hive, $path) ... } → 레지스트리 경로
        [string]$RedirectExe = 'C:\ProgramData\LiteWin\bin\LiteWinEdgeRedirect.exe'
    )
    $removed = @()

    # ---- 파일 ----
    foreach ($d in "$MountDir\Program Files (x86)\Microsoft\Edge", "$MountDir\Program Files\Microsoft\Edge") {
        if (Remove-ProtectedPath $d) { $removed += $d.Substring($MountDir.Length) }
    }
    foreach ($l in "$MountDir\ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
                   "$MountDir\Users\Public\Desktop\Microsoft Edge.lnk",
                   "$MountDir\Users\Default\Desktop\Microsoft Edge.lnk",
                   "$MountDir\Users\Default\AppData\Roaming\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk") {
        if (Test-Path -LiteralPath $l) { Remove-Item -LiteralPath $l -Force -ErrorAction SilentlyContinue; $removed += $l.Substring($MountDir.Length) }
    }

    # ---- 레지스트리: 설치 기록 / 브라우저 등록 / ProgId / 실행 경로 ----
    $keys = @(
        'Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
        'WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge'
        'Clients\StartMenuInternet\Microsoft Edge'
        'WOW6432Node\Clients\StartMenuInternet\Microsoft Edge'
        'Classes\MSEdgeHTM', 'Classes\MSEdgePDF', 'Classes\MSEdgeMHT'
        'Microsoft\Windows\CurrentVersion\App Paths\msedge.exe'
        "WOW6432Node\Microsoft\EdgeUpdate\Clients\$script:EdgeStableGuidOffline"
        "Microsoft\EdgeUpdate\Clients\$script:EdgeStableGuidOffline"
    )
    foreach ($k in $keys) {
        $p = & $HivePath 'SOFTWARE' $k
        if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue; $removed += "HKLM\$k" }
    }
    $ra = & $HivePath 'SOFTWARE' 'RegisteredApplications'
    Remove-ItemProperty -LiteralPath $ra -Name 'Microsoft Edge' -ErrorAction SilentlyContinue

    # '연결 프로그램' 목록에서 Edge 제거 (모든 확장자의 OpenWithProgids)
    $classes = & $HivePath 'SOFTWARE' 'Classes'
    $cleaned = 0
    foreach ($ext in Get-ChildItem -LiteralPath $classes -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '.*' }) {
        $owp = Join-Path $ext.PSPath 'OpenWithProgids'
        $item = Get-Item -LiteralPath $owp -ErrorAction SilentlyContinue
        if (-not $item) { continue }
        foreach ($n in $item.GetValueNames()) {
            if ($n -like 'MSEdge*') { Remove-ItemProperty -LiteralPath $owp -Name $n -ErrorAction SilentlyContinue; $cleaned++ }
        }
    }

    # microsoft-edge: 링크 → LiteWin 리다이렉트 (기본 브라우저로)
    $proto = & $HivePath 'SOFTWARE' 'Classes\microsoft-edge'
    Set-RegValue $proto '(default)' 'URL:microsoft-edge' String
    Set-RegValue $proto 'URL Protocol' '' String
    Set-RegValue "$proto\shell\open\command" '(default)' "`"$RedirectExe`" `"%1`"" String
    Remove-ItemProperty -LiteralPath "$proto\shell\open\command" -Name 'DelegateExecute' -ErrorAction SilentlyContinue

    # Edge 재설치 금지, WebView2 설치/업데이트는 허용
    $pol = & $HivePath 'SOFTWARE' 'Policies\Microsoft\EdgeUpdate'
    Set-RegValue $pol "Install$script:EdgeStableGuidOffline" 0
    Set-RegValue $pol 'CreateDesktopShortcutDefault' 0
    Set-RegValue $pol "Install$script:WebView2GuidOffline" 1
    Set-RegValue $pol "Update$script:WebView2GuidOffline" 1
    Set-RegValue (& $HivePath 'SOFTWARE' 'Microsoft\EdgeUpdate') 'DoNotUpdateToEdgeWithChromium' 1

    [pscustomobject]@{ Removed = $removed; OpenWithCleaned = $cleaned }
}
