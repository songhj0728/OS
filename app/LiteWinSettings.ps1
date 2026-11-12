<#
    LiteWin 설정 (시작 메뉴 > LiteWin 설정)
    - 모드: 라이트 윈도우 / 맥 입력 / 맥 입력 + UI  (언제든 왔다갔다)
    - 사진·동영상 추가 형식, 게임 플랫폼, 맥 UI 도구 설치 (모두 선택 사항, 건너뛰기 가능)
    - 브라우저: Chrome 기본, Edge 제거/리다이렉트
    창은 열었을 때만 실행된다(상주 없음). 적용은 별도 콘솔 창(Apply-LiteWin.ps1)에서 진행.

    -FirstRun : 첫 로그인 마법사 모드 (프로필 기본 선택값을 미리 체크)
#>
param([switch]$FirstRun)

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib\LiteWin.Common.ps1')
. (Join-Path $root 'lib\LiteWin.Apps.ps1')

# 관리자 권한으로 다시 실행
if (-not (Test-LWAdmin)) {
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$PSCommandPath`"")
    if ($FirstRun) { $argList += '-FirstRun' }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argList
    exit
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()

$catalog = Get-LWCatalog
$state   = Get-LWState
$lwProfile = Get-LWProfile
$machine = $null
$machineFile = Join-Path $script:LWRoot 'machine.json'
if (Test-Path $machineFile) { $machine = Get-Content $machineFile -Raw -Encoding UTF8 | ConvertFrom-Json }

# 미리 선택할 값: 첫 실행이면 프로필 기본값, 아니면 현재 상태
$defaults   = $lwProfile.Defaults
$curMode    = if ($FirstRun -and $defaults.Mode) { $defaults.Mode } else { $state.Mode }
if (-not $curMode) { $curMode = 'Lite' }
$curUi      = @($state.UiOptions)
if ($FirstRun -and $defaults.UiOptions) { $curUi = @($defaults.UiOptions) }
$preApps    = if ($FirstRun) { @($defaults.Apps) } else { @() }
$keysState  = $state.Keys

$font  = New-Object Drawing.Font('Malgun Gothic', 9)
$bold  = New-Object Drawing.Font('Malgun Gothic', 10, [Drawing.FontStyle]::Bold)
$small = New-Object Drawing.Font('Malgun Gothic', 8)
$gray  = [Drawing.Color]::DimGray

$form = New-Object Windows.Forms.Form
$form.Text = if ($FirstRun) { 'LiteWin 시작하기' } else { 'LiteWin 설정' }
$form.Size = New-Object Drawing.Size(640, 600)
$form.StartPosition = 'CenterScreen'
$form.Font = $font
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false

$tabs = New-Object Windows.Forms.TabControl
$tabs.Location = New-Object Drawing.Point(10, 10)
$tabs.Size = New-Object Drawing.Size(605, 490)
$form.Controls.Add($tabs)

function New-Page([string]$title) {
    $page = New-Object Windows.Forms.TabPage $title
    $flow = New-Object Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'; $flow.FlowDirection = 'TopDown'; $flow.WrapContents = $false
    $flow.AutoScroll = $true; $flow.Padding = New-Object Windows.Forms.Padding(10)
    $page.Controls.Add($flow); $tabs.TabPages.Add($page)
    return $flow
}
function Add-Label($panel, [string]$text, $f = $font, $color = $null, [int]$top = 0) {
    $l = New-Object Windows.Forms.Label
    $l.Text = $text; $l.Font = $f; $l.AutoSize = $true; $l.MaximumSize = New-Object Drawing.Size(560, 0)
    $l.Margin = New-Object Windows.Forms.Padding(3, $top, 3, 3)
    if ($color) { $l.ForeColor = $color }
    $panel.Controls.Add($l); return $l
}
function Add-Check($panel, [string]$text, [bool]$checked, [int]$indent = 0) {
    $cb = New-Object Windows.Forms.CheckBox
    $cb.Text = $text; $cb.Checked = $checked; $cb.AutoSize = $true
    $cb.Margin = New-Object Windows.Forms.Padding((3 + $indent), 2, 3, 2)
    $panel.Controls.Add($cb); return $cb
}
function Add-Radio($panel, [string]$text, [bool]$checked) {
    $rb = New-Object Windows.Forms.RadioButton
    $rb.Text = $text; $rb.Checked = $checked; $rb.AutoSize = $true; $rb.Font = $bold
    $rb.Margin = New-Object Windows.Forms.Padding(3, 8, 3, 0)
    $panel.Controls.Add($rb); return $rb
}
function Get-KeyOpt($name) {
    if ($keysState -and ($keysState.PSObject.Properties.Name -contains $name)) { return [bool]$keysState.$name }
    return $true
}

$appChecks = @{}   # 카탈로그 id → CheckBox
function Add-CatalogSection($panel, [string]$categoryId, [int]$indent = 0) {
    foreach ($app in @($catalog.apps | Where-Object category -eq $categoryId)) {
        $cb = Add-Check $panel $app.name ($preApps -contains $app.id) $indent
        if ($app.unavailable) { $cb.Enabled = $false; $cb.Checked = $false; $cb.Text += '  (아직 배포 전)' }
        $appChecks[$app.id] = $cb
        if ($app.description) { [void](Add-Label $panel ("    " + $app.description) $small $gray) }
    }
}

# ============================================================== 탭 1: 모드
$p1 = New-Page '모드'
[void](Add-Label $p1 '조작 방식과 화면 스타일을 고르세요. 언제든 이 창에서 다시 바꿀 수 있습니다.')
$rbLite = Add-Radio $p1 '라이트 윈도우' ($curMode -eq 'Lite')
[void](Add-Label $p1 '    일반 Windows 조작 그대로. 상주 프로그램 없음' $small $gray)
$rbMac  = Add-Radio $p1 '맥 입력' ($curMode -eq 'MacInput')
[void](Add-Label $p1 '    왼쪽 Alt = ⌘, 왼쪽 Win = ⌥, Caps Lock = 한/영, 맥 마우스 가속, 트랙패드 제스처 (약 3MB)' $small $gray)
$rbUi   = Add-Radio $p1 '맥 입력 + UI 스타일' ($curMode -eq 'MacUI')
[void](Add-Label $p1 '    위 기능 + 아래에서 고른 화면 스타일' $small $gray)

$uiChecks = [ordered]@{}
$uiChecks['DarkMode']        = Add-Check $p1 '다크 모드' ($curUi -contains 'DarkMode') 24
$uiChecks['AutoHideTaskbar'] = Add-Check $p1 '작업표시줄 자동 숨기기 (Dock 처럼)' ($curUi -contains 'AutoHideTaskbar') 24
$uiChecks['Transparency']    = Add-Check $p1 '투명 효과' ($curUi -contains 'Transparency') 24
foreach ($id in 'quicklook', 'flow', 'windhawk') {
    $app = $catalog.apps | Where-Object id -eq $id
    $uiChecks[$id] = Add-Check $p1 ($app.name + '  — 설치 필요') ($curUi -contains $id) 24
}
function Update-UiEnabled { foreach ($cb in $uiChecks.Values) { $cb.Enabled = $rbUi.Checked } }
$rbUi.add_CheckedChanged({ Update-UiEnabled }); Update-UiEnabled

[void](Add-Label $p1 '맥 입력 세부 설정' $bold $null 12)
$kbCaps  = Add-Check $p1 'Caps Lock 짧게 = 한/영 전환' (Get-KeyOpt 'CapsLockToHangul') 12
$kbWord  = Add-Check $p1 '⌥←/→ 단어 이동 (창 스냅은 ⌃⌘방향키로 이동)' (Get-KeyOpt 'OptionWordMove') 12
$kbQuit  = Add-Check $p1 '⌘Q = 앱 종료' (Get-KeyOpt 'CmdQuitApp') 12
$kbWheel = Add-Check $p1 '마우스 휠 자연스러운 스크롤 (맥 방향)' ($(if ($null -ne $state.NaturalMouseWheel) { [bool]$state.NaturalMouseWheel } else { $true })) 12
function Update-KeysEnabled { foreach ($cb in $kbCaps, $kbWord, $kbQuit, $kbWheel) { $cb.Enabled = -not $rbLite.Checked } }
$rbLite.add_CheckedChanged({ Update-KeysEnabled }); Update-KeysEnabled

# ============================================================== 탭 2: 사진·동영상
$p2 = New-Page '사진·동영상'
[void](Add-Label $p2 '기본은 Windows 사진 / 미디어 플레이어입니다. 더 많은 형식(EXIF, VP9, HEVC, RAW 등)이 필요할 때만 고르세요.')
Add-CatalogSection $p2 'media'

# ============================================================== 탭 3: 게임
$p3 = New-Page '게임'
[void](Add-Label $p3 '설치할 게임 플랫폼을 고르세요. 너무 많으면 비워두거나 [모두 해제] 를 누르세요.')
$tpm = Test-TpmSecureBoot
if (-not $tpm.Ok) { [void](Add-Label $p3 "⚠ 이 PC: TPM=$($tpm.Tpm), 보안 부팅=$($tpm.SecureBoot) — 발로란트(Vanguard) 는 실행되지 않을 수 있습니다" $small ([Drawing.Color]::DarkOrange)) }
$btnNone = New-Object Windows.Forms.Button
$btnNone.Text = '모두 해제 (아무것도 설치하지 않기)'; $btnNone.AutoSize = $true
$p3.Controls.Add($btnNone)
[void](Add-Label $p3 '게임 플랫폼' $bold $null 8)
Add-CatalogSection $p3 'gaming' 8
[void](Add-Label $p3 '커뮤니티 · 브라우저' $bold $null 8)
Add-CatalogSection $p3 'community' 8
[void](Add-Label $p3 '드라이버' $bold $null 8)
Add-CatalogSection $p3 'drivers' 8
$btnNone.add_Click({
    foreach ($cat in 'gaming', 'community', 'drivers') {
        foreach ($a in @($catalog.apps | Where-Object category -eq $cat)) { $appChecks[$a.id].Checked = $false }
    }
})

# ============================================================== 탭 4: 브라우저
$p4 = New-Page '브라우저'
[void](Add-Label $p4 '기본 브라우저: Google Chrome' $bold)
[void](Add-Label $p4 '설치 시 Chrome 이 기본 브라우저로 지정됩니다. 다른 브라우저를 쓰려면 설치 후 설정 > 앱 > 기본 앱 에서 바꾸세요.' $small $gray)
$removeEdge = if ($machine) { [bool]$machine.RemoveEdge } else { $true }
$redirect   = if ($machine) { [bool]$machine.EdgeRedirect } else { $true }
$cbEdge  = Add-Check $p4 'Edge 브라우저 제거 (WebView2 런타임은 유지)' $removeEdge
[void](Add-Label $p4 '    해제하고 적용하면 Edge 를 다시 설치합니다' $small $gray)
$cbRedir = Add-Check $p4 'Edge 전용 링크(microsoft-edge:)를 Chrome 으로 열기' $redirect
$cbEdge.add_CheckedChanged({ $cbRedir.Enabled = $cbEdge.Checked }); $cbRedir.Enabled = $cbEdge.Checked

# ============================================================== 하단 버튼
$btnApply = New-Object Windows.Forms.Button
$btnApply.Text = '적용'; $btnApply.Size = New-Object Drawing.Size(110, 32)
$btnApply.Location = New-Object Drawing.Point(505, 515)
$btnSkip = New-Object Windows.Forms.Button
$btnSkip.Text = '앱 설치 건너뛰기'; $btnSkip.Size = New-Object Drawing.Size(230, 32)
$btnSkip.Location = New-Object Drawing.Point(265, 515)
$btnClose = New-Object Windows.Forms.Button
$btnClose.Text = '닫기'; $btnClose.Size = New-Object Drawing.Size(80, 32)
$btnClose.Location = New-Object Drawing.Point(10, 515)
$form.Controls.AddRange(@($btnApply, $btnSkip, $btnClose))
$form.AcceptButton = $btnApply

function Start-Apply([bool]$installApps) {
    $mode = if ($rbUi.Checked) { 'MacUI' } elseif ($rbMac.Checked) { 'MacInput' } else { 'Lite' }
    $ui = @(); foreach ($k in $uiChecks.Keys) { if ($uiChecks[$k].Checked -and $mode -eq 'MacUI') { $ui += $k } }
    $apps = @()
    if ($installApps) {
        foreach ($k in $appChecks.Keys) { if ($appChecks[$k].Checked -and $appChecks[$k].Enabled) { $apps += $k } }
    }
    # 맥 UI 도구를 켰는데 설치 목록에 없으면 함께 설치
    foreach ($id in 'quicklook', 'flow', 'windhawk') { if ($ui -contains $id -and $apps -notcontains $id) { $apps += $id } }

    $choices = [ordered]@{
        Mode = $mode; UiOptions = $ui; Apps = $apps; FirstRun = [bool]$FirstRun
        NaturalMouseWheel = $kbWheel.Checked
        Keys = @{ CapsLockToHangul = $kbCaps.Checked; OptionWordMove = $kbWord.Checked; CmdQuitApp = $kbQuit.Checked }
        RemoveEdge = $cbEdge.Checked; EdgeRedirect = $cbRedir.Checked
    }
    $file = Join-Path $env:TEMP ("litewin-choices-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $choices | ConvertTo-Json -Depth 4 | Set-Content $file -Encoding UTF8
    Start-Process powershell.exe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
        "`"$(Join-Path $PSScriptRoot 'Apply-LiteWin.ps1')`"", '-ChoicesFile', "`"$file`"")
    $form.Close()
}

$btnApply.add_Click({ Start-Apply $true })
$btnSkip.add_Click({
    if ($FirstRun) {
        # 첫 실행 건너뛰기: 앱은 하나도 설치하지 않고, 고른 모드만 적용
        Start-Apply $false
    } else {
        $form.Close()
    }
})
$btnClose.add_Click({ $form.Close() })

[void]$form.ShowDialog()
