<#
    LiteWin 설정 (시작 메뉴 > LiteWin 설정)
    - 모드: 라이트 윈도우 / 맥 입력 / 맥 입력 + UI  (언제든 왔다갔다)
    - 사진·동영상 추가 형식, 게임 플랫폼, 맥 UI 도구 설치 (모두 선택 사항, 건너뛰기 가능)
    - 브라우저: Chrome 기본, Edge 제거/리다이렉트
    창은 열었을 때만 실행된다(상주 없음). 적용은 별도 콘솔 창(Apply-LiteWin.ps1)에서 진행.

    -FirstRun     : 첫 로그인 마법사 모드 (프로필 기본 선택값을 미리 체크, 전체 화면)
    -ApplyPending : Administrator 계정으로 바꾼 뒤 첫 로그인 — 저장해 둔 선택을 적용하고 이전 계정을 지운다
#>
param([switch]$FirstRun, [switch]$ApplyPending)

$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'lib\LiteWin.Common.ps1')
. (Join-Path $root 'lib\LiteWin.Apps.ps1')
. (Join-Path $root 'lib\LiteWin.Components.ps1')
. (Join-Path $root 'lib\LiteWin.Browsers.ps1')
. (Join-Path $root 'lib\LiteWin.Theme.ps1')
. (Join-Path $root 'lib\LiteWin.Activation.ps1')

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
function Get-KeyOpt($name, [bool]$default = $true) {
    if ($keysState -and ($keysState.PSObject.Properties.Name -contains $name)) { return [bool]$keysState.$name }
    return $default
}
$shellState = $state.Shell
function Get-ShellOpt($name, $default) {
    if ($shellState -and ($shellState.PSObject.Properties.Name -contains $name)) { return $shellState.$name }
    return $default
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

# ============================================================== 탭 0: 계정 (첫 실행에서만)
$acct = $null
if ($FirstRun) {
    $p0 = New-Page '계정'
    [void](Add-Label $p0 '이 PC 에서 쓸 이름을 정하세요. 비워 두면 "user" 로 만듭니다.' $bold)
    function New-TextRow($panel, [string]$label, [switch]$Password) {
        $row = New-Object Windows.Forms.FlowLayoutPanel; $row.AutoSize = $true; $row.WrapContents = $false
        $row.Margin = New-Object Windows.Forms.Padding(12, 4, 3, 2)
        $l = New-Object Windows.Forms.Label; $l.Text = $label; $l.Width = 130; $l.Margin = New-Object Windows.Forms.Padding(0, 6, 3, 0)
        $t = New-Object Windows.Forms.TextBox; $t.Width = 220; if ($Password) { $t.UseSystemPasswordChar = $true }
        $row.Controls.AddRange(@($l, $t)); $panel.Controls.Add($row); return $t
    }
    $txtName  = New-TextRow $p0 '사용자 이름'
    $txtPw    = New-TextRow $p0 '암호 (선택)' -Password
    $txtPw2   = New-TextRow $p0 '암호 확인' -Password
    [void](Add-Label $p0 '    암호를 비워 두면 암호 없이 로그인합니다. 다른 사람이 쓰는 PC 라면 암호를 정하세요.' $small $gray)

    [void](Add-Label $p0 '계정 종류' $bold $null 14)
    $rbAcctUser  = Add-Radio $p0 '일반 계정 (권장) — 위 이름으로, 필요할 때만 관리자 권한 확인' $true
    $rbAcctUser.Font = $font
    $rbAcctAdmin = Add-Radio $p0 'Administrator 계정 하나만 사용 — 위 계정을 지우고 기본 제공 Administrator 로 바꿈' $false
    $rbAcctAdmin.Font = $font
    $txtAdm  = New-TextRow $p0 'Administrator 암호' -Password
    $txtAdm2 = New-TextRow $p0 '암호 확인' -Password
    $txtAdm.Enabled = $false; $txtAdm2.Enabled = $false
    $script:adminConfirmed = $false
    $rbAcctAdmin.add_CheckedChanged({
        if ($rbAcctAdmin.Checked -and -not $script:adminConfirmed) {
            $m1 = "기본 제공 Administrator 계정은 사용자 계정 컨트롤(UAC) 확인 없이 모든 프로그램이 최고 권한으로 실행됩니다.`n`n" +
                  "- 악성 프로그램이 확인 창 없이 시스템 전체를 바꿀 수 있습니다`n- 실수로 시스템 파일을 지워도 막아 주지 않습니다`n- 일부 Store 앱과 보안 기능이 제한될 수 있습니다`n`n계속할까요?"
            $r1 = [Windows.Forms.MessageBox]::Show($m1, '보안 경고 (1/2)', 'YesNo', 'Warning', 'Button2')
            $r2 = 'No'
            if ($r1 -eq 'Yes') {
                $r2 = [Windows.Forms.MessageBox]::Show("한 번 더 확인합니다.`n`n지금 계정('$env:USERNAME')과 그 안의 파일이 지워지고, 이 PC 에는 Administrator 계정 하나만 남습니다. Administrator 에는 반드시 암호를 정해야 합니다.`n`n정말 바꿀까요?", '보안 경고 (2/2)', 'YesNo', 'Warning', 'Button2')
            }
            if ($r2 -ne 'Yes') { $rbAcctUser.Checked = $true; return }
            $script:adminConfirmed = $true
        }
        $on = $rbAcctAdmin.Checked
        $txtAdm.Enabled = $on; $txtAdm2.Enabled = $on
        $txtName.Enabled = -not $on; $txtPw.Enabled = -not $on; $txtPw2.Enabled = -not $on
    })

    function Invoke-AccountSetup {
        <# 창에서 바로 처리한다 (암호를 파일에 남기지 않기 위해). 실패하면 $false #>
        $name = $txtName.Text.Trim()
        if (-not $name) { $name = 'user' }
        if ($name.Length -gt 20 -or $name -match '["/\\\[\]:;|=,+*?<>@]') {
            [Windows.Forms.MessageBox]::Show('이름은 20자 이하이고 " / \ [ ] : ; | = , + * ? < > @ 를 쓸 수 없습니다.', 'LiteWin') | Out-Null; return $false
        }
        if ($txtPw.Text -ne $txtPw2.Text) { [Windows.Forms.MessageBox]::Show('암호가 서로 다릅니다.', 'LiteWin') | Out-Null; return $false }
        if ($rbAcctAdmin.Checked) {
            if (-not $txtAdm.Text) { [Windows.Forms.MessageBox]::Show('Administrator 계정에는 암호가 꼭 필요합니다.', 'LiteWin') | Out-Null; return $false }
            if ($txtAdm.Text -ne $txtAdm2.Text) { [Windows.Forms.MessageBox]::Show('Administrator 암호가 서로 다릅니다.', 'LiteWin') | Out-Null; return $false }
        }
        try {
            $me = $env:USERNAME
            if ($rbAcctAdmin.Checked) {
                # Administrator 하나만: 켜고 암호를 정한 뒤, 지금 계정은 Administrator 첫 로그인 때 지운다
                $adm = Get-LocalUser | Where-Object { $_.SID.Value -like 'S-1-5-*-500' } | Select-Object -First 1
                Set-LocalUser -SID $adm.SID -Password (ConvertTo-SecureString $txtAdm.Text -AsPlainText -Force) -ErrorAction Stop
                Enable-LocalUser -SID $adm.SID -ErrorAction Stop
                $script:AdminHandoff = @{ OldUser = $me; Admin = $adm.Name }
                Write-LWLog "Administrator 계정 하나만 사용 선택 (경고 2회 확인) — '$me' 는 Administrator 첫 로그인 때 삭제" WARN
                return $true
            }
            if ($name -ne $me) { Rename-LocalUser -Name $me -NewName $name -ErrorAction Stop }
            Set-LocalUser -Name $name -FullName $name -ErrorAction SilentlyContinue
            if ($txtPw.Text) { Set-LocalUser -Name $name -Password (ConvertTo-SecureString $txtPw.Text -AsPlainText -Force) -ErrorAction Stop }
            Write-LWLog "계정 이름: $name (로그아웃 후 표시 반영)"
            return $true
        } catch {
            [Windows.Forms.MessageBox]::Show("계정 설정 실패: $($_.Exception.Message)", 'LiteWin') | Out-Null; return $false
        }
    }
}

# ============================================================== 탭 1: 모드
$p1 = New-Page '모드'
[void](Add-Label $p1 '조작 방식과 화면 스타일을 고르세요. 언제든 이 창에서 다시 바꿀 수 있습니다.')
$rbLite = Add-Radio $p1 '라이트 윈도우' ($curMode -eq 'Lite')
[void](Add-Label $p1 '    일반 Windows 조작. 화면은 클래식 구조(아래 선택)' $small $gray)
$rbMac  = Add-Radio $p1 '맥 입력' ($curMode -eq 'MacInput')
[void](Add-Label $p1 '    왼쪽 Alt = ⌘, 왼쪽 Win = ⌥, Caps Lock = 한/영, 맥 F열, 마우스 가속, 트랙패드 제스처. 화면은 클래식 구조' $small $gray)
function New-Combo($panel, [string[]]$items, [int]$index, [int]$indent = 44) {
    $c = New-Object Windows.Forms.ComboBox
    $c.DropDownStyle = 'DropDownList'; $c.Width = 300
    $c.Margin = New-Object Windows.Forms.Padding($indent, 0, 3, 4)
    [void]$c.Items.AddRange($items); $c.SelectedIndex = $index
    $panel.Controls.Add($c); return $c
}
$shBar   = Add-Check $p1 '클래식 작업표시줄' ([bool](Get-ShellOpt 'ClassicTaskbar' $true)) 24
$cbEngine = New-Combo $p1 @('Windows 10 스타일 (ExplorerPatcher)', 'Windows 95~7 스타일 (RetroBar)') $(if ((Get-ShellOpt 'ClassicEngine' 'ep') -eq 'retrobar') { 1 } else { 0 })
$shStart = Add-Check $p1 '클래식 시작 메뉴' ([bool](Get-ShellOpt 'ClassicStart' $true)) 24
$cbStart = New-Combo $p1 @('Windows 7 스타일 (Open-Shell)', 'Windows 10 스타일 (ExplorerPatcher)') $(if ((Get-ShellOpt 'StartEngine' 'openshell') -eq 'ep') { 1 } else { 0 })
$shLabels = Add-Check $p1 '작업표시줄 단추 펼쳐 보기 (프로그램 이름 표시, 묶지 않기)' ([bool](Get-ShellOpt 'TaskbarLabels' $false)) 24
$rbUi   = Add-Radio $p1 '맥 입력 + UI 스타일' ($curMode -eq 'MacUI')
[void](Add-Label $p1 '    맥 입력 + Dock(가운데 작업표시줄) + 아래에서 고른 화면 스타일' $small $gray)

$uiChecks = [ordered]@{}
$uiChecks['DarkMode']        = Add-Check $p1 '다크 모드' ($curUi -contains 'DarkMode') 24
$uiChecks['AutoHideTaskbar'] = Add-Check $p1 '작업표시줄 자동 숨기기 (Dock 처럼)' ($curUi -contains 'AutoHideTaskbar') 24
$uiChecks['Transparency']    = Add-Check $p1 '투명 효과' ($curUi -contains 'Transparency') 24
foreach ($id in 'quicklook', 'flow', 'windhawk') {
    $app = $catalog.apps | Where-Object id -eq $id
    $uiChecks[$id] = Add-Check $p1 ($app.name + '  — 설치 필요') ($curUi -contains $id) 24
}
$capLabel = Add-Label $p1 '    창 버튼 (모든 창 왼쪽 위에 맥식 버튼 추가, 원래 버튼은 그대로)' $small $gray
$cbCaption = New-Object Windows.Forms.ComboBox
$cbCaption.DropDownStyle = 'DropDownList'; $cbCaption.Width = 330
$cbCaption.Margin = New-Object Windows.Forms.Padding(27, 0, 3, 4)
[void]$cbCaption.Items.AddRange(@('끔', '닫기 · 최소화 · 전체화면 (3개)', '전체화면 버튼만'))
$cbCaption.SelectedIndex = switch (Get-ShellOpt 'Caption' 'traffic') { 'off' { 0 } 'fullscreen' { 2 } default { 1 } }
$p1.Controls.Add($cbCaption)
function Update-UiEnabled {
    foreach ($cb in $uiChecks.Values) { $cb.Enabled = $rbUi.Checked }
    $cbCaption.Enabled = $rbUi.Checked
    foreach ($c in $shBar, $shStart, $shLabels, $cbEngine, $cbStart) { $c.Enabled = -not $rbUi.Checked }
}
$rbUi.add_CheckedChanged({ Update-UiEnabled }); Update-UiEnabled

[void](Add-Label $p1 '맥 입력 세부 설정' $bold $null 12)
$kbCaps  = Add-Check $p1 'Caps Lock 짧게 = 한/영 전환' (Get-KeyOpt 'CapsLockToHangul') 12
$kbWord  = Add-Check $p1 '⌥←/→ 단어 이동 (창 스냅은 ⌃⌘방향키로 이동)' (Get-KeyOpt 'OptionWordMove') 12
$kbQuit  = Add-Check $p1 '⌘Q = 앱 종료' (Get-KeyOpt 'CmdQuitApp') 12
$kbF     = Add-Check $p1 'F열 맥 기본 (F1/F2 밝기, F3 작업 보기, F4 검색, F7~F9 미디어, F10~F12 볼륨)' (Get-KeyOpt 'MacFKeys') 12
$kbStdF  = Add-Check $p1 'F1, F2 등을 표준 기능 키로 사용 (⌥+F키 = 맥 기능)' (Get-KeyOpt 'StandardFKeys' $false) 24
$kbGame  = Add-Check $p1 '전체화면 게임에서는 맥 단축키 끄기 (기본: 어디서나 동일)' (Get-KeyOpt 'GameAutoOff' $false) 12
$kbWheel = Add-Check $p1 '마우스 휠 자연스러운 스크롤 (맥 방향)' ($(if ($null -ne $state.NaturalMouseWheel) { [bool]$state.NaturalMouseWheel } else { $true })) 12
function Update-KeysEnabled { foreach ($cb in $kbCaps, $kbWord, $kbQuit, $kbF, $kbStdF, $kbGame, $kbWheel) { $cb.Enabled = -not $rbLite.Checked } }
$rbMac.add_CheckedChanged({ Update-UiEnabled }); $rbLite.add_CheckedChanged({ Update-UiEnabled })
$rbLite.add_CheckedChanged({ Update-KeysEnabled }); Update-KeysEnabled

# ============================================================== 탭: 테마 (정품 인증 전에도 동작)
$pT = New-Page '테마'
[void](Add-Label $pT '배경화면과 다크/라이트 모드를 함께 바꿉니다. 고르면 바로 적용됩니다.')
[void](Add-Label $pT '    Windows 정품 인증 전에는 설정 앱의 개인 설정이 잠기지만, 여기서는 인증과 관계없이 바꿀 수 있습니다.' $small $gray)
$curTheme = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' -ErrorAction SilentlyContinue).CurrentTheme
$grid = New-Object Windows.Forms.FlowLayoutPanel
$grid.AutoSize = $true; $grid.MaximumSize = New-Object Drawing.Size(570, 0); $grid.WrapContents = $true
$grid.Margin = New-Object Windows.Forms.Padding(6, 8, 3, 3)
$pT.Controls.Add($grid)
foreach ($th in @(Get-LWThemes)) {
    $cell = New-Object Windows.Forms.FlowLayoutPanel
    $cell.FlowDirection = 'TopDown'; $cell.AutoSize = $true; $cell.Margin = New-Object Windows.Forms.Padding(6)
    $pic = New-Object Windows.Forms.PictureBox
    $pic.Size = New-Object Drawing.Size(168, 95); $pic.SizeMode = 'Zoom'; $pic.Cursor = 'Hand'
    $pic.BorderStyle = if ($curTheme -and $curTheme -eq $th.File) { 'Fixed3D' } else { 'FixedSingle' }
    if ($th.Wallpaper -and (Test-Path $th.Wallpaper)) {
        try {
            # 원본을 잠그지 않도록 작게 복사한 미리보기만 쓴다
            $src = [Drawing.Image]::FromFile($th.Wallpaper); $pic.Image = $src.GetThumbnailImage(336, 190, $null, [IntPtr]::Zero); $src.Dispose()
        } catch { }
    }
    $lab = New-Object Windows.Forms.Label
    $lab.Text = $th.Name + $(if ($th.Dark) { '  ·  다크' } else { '  ·  라이트' }); $lab.AutoSize = $true
    $cell.Controls.AddRange(@($pic, $lab)); $grid.Controls.Add($cell)
    # 클로저(GetNewClosure)를 쓰면 이 스크립트의 함수(Set-LWTheme)가 보이지 않으므로, 테마 정보는 Tag 에 담는다
    $pic.Tag = @{ Theme = $th; Pic = $pic }; $lab.Tag = $pic.Tag
    $onPick = {
        param($sender, $e)
        $t = $sender.Tag
        [void](Set-LWTheme -Theme $t.Theme)
        foreach ($c in $grid.Controls) { $c.Controls[0].BorderStyle = 'FixedSingle' }
        $t.Pic.BorderStyle = 'Fixed3D'
    }
    $pic.add_Click($onPick); $lab.add_Click($onPick)
}

# ============================================================== 탭 2: 사진·동영상
$p2 = New-Page '사진·동영상'
[void](Add-Label $p2 '동영상(HEVC 포함)은 MPC-BE, 아이폰 사진(.heic)은 ImageGlass 로 바로 열리도록 이미 설치되어 있습니다. 그 밖의 사진은 Windows 사진 앱. 탐색기 미리보기·사진 앱에서도 VP9/AV1/RAW 등을 보려면 아래 코덱 팩을 고르세요.')
Add-CatalogSection $p2 'media'

# ============================================================== 탭 3: 게임 (Gaming 프로필에서만)
$isGaming = "$($lwProfile.Name)" -eq 'Gaming'
if ($isGaming) {
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
}

# ============================================================== 탭 4: 브라우저
$p4 = New-Page '브라우저'
[void](Add-Label $p4 '설치할 브라우저에 체크하고, 기본으로 쓸 브라우저를 고르세요. 체크를 해제하고 적용하면 그 브라우저를 지웁니다.')
[void](Add-Label $p4 '    마지막 남은 브라우저는 지우지 않습니다. 기본 브라우저를 바꾸면 Windows 기본 앱 화면이 열리니 [기본값으로 설정] 을 눌러 주세요.' $small $gray)
$installedBrowsers = @(Get-LWInstalledBrowsers)
$curDefault = Get-LWDefaultBrowserId
$browserRows = [ordered]@{}
foreach ($bid in $script:LWBrowsers.Keys) {
    $b = $script:LWBrowsers[$bid]
    $row = New-Object Windows.Forms.FlowLayoutPanel
    $row.AutoSize = $true; $row.WrapContents = $false; $row.Margin = New-Object Windows.Forms.Padding(12, 2, 3, 2)
    $cbI = New-Object Windows.Forms.CheckBox
    $cbI.Text = $b.Name + $(if ($installedBrowsers -contains $bid) { '  (설치됨)' } else { '' }); $cbI.Width = 230
    $cbI.Checked = $installedBrowsers -contains $bid
    $rbD = New-Object Windows.Forms.RadioButton
    $rbD.Text = '기본'; $rbD.AutoSize = $true; $rbD.Checked = ($bid -eq $curDefault)
    $row.Controls.AddRange(@($cbI, $rbD)); $p4.Controls.Add($row)
    $browserRows[$bid] = @{ Install = $cbI; Default = $rbD }
    $cbI.add_CheckedChanged({ foreach ($r in $browserRows.Values) { $r.Default.Enabled = $r.Install.Checked } }.GetNewClosure())
}
foreach ($r in $browserRows.Values) { $r.Default.Enabled = $r.Install.Checked }
$redirect = if ($machine -and $null -ne $machine.EdgeRedirect) { [bool]$machine.EdgeRedirect } else { $true }
$cbRedir = Add-Check $p4 'Edge 가 없을 때 Edge 전용 링크(microsoft-edge:)를 기본 브라우저로 열기' $redirect
[void](Add-Label $p4 '    Edge 를 지워도 WebView2 런타임은 남겨 둡니다 (여러 앱이 화면 표시에 사용).' $small $gray)

function Get-BrowserChoices {
    $want = @(); $default = $null
    foreach ($k in $browserRows.Keys) {
        if ($browserRows[$k].Install.Checked) { $want += $k }
        if ($browserRows[$k].Default.Checked -and $browserRows[$k].Install.Checked) { $default = $k }
    }
    if (-not $want.Count) { [Windows.Forms.MessageBox]::Show('브라우저를 하나 이상 남겨 두어야 인터넷을 쓸 수 있습니다.', 'LiteWin') | Out-Null; return $null }
    if (-not $default) { $default = $want[0] }
    [pscustomobject]@{
        Install = @($want | Where-Object { $installedBrowsers -notcontains $_ -and $_ -ne 'edge' })
        Remove  = @($installedBrowsers | Where-Object { $want -notcontains $_ -and $_ -ne 'edge' })
        Default = $default
        Edge    = ($want -contains 'edge')
    }
}

# ============================================================== 탭 5: 정보 (구성요소)
$p5 = New-Page '정보'
$cst = Get-LWComponentState
[void](Add-Label $p5 '셸 구성요소는 Windows Update 와 함께 자동으로 관리됩니다. 따로 신경 쓰지 않아도 됩니다.' $bold)
$epi = Get-EPInstalled
$verLines = @(
    ('ExplorerPatcher : ' + $(if ($epi) { $epi.RawVersion } elseif ($cst.EpSuspended) { '기능 업데이트 보호 중 (업그레이드 후 자동 재설치)' } else { '없음 (RetroBar 사용)' }))
)
$keysExe = Join-Path $script:LWRoot 'bin\LiteWinKeys.exe'
$verLines += ('{0,-16}: {1}' -f '맥 입력 엔진', $(if (Test-Path $keysExe) { (Get-Item $keysExe).VersionInfo.FileVersion } else { '없음 (맥 입력을 켤 때 준비)' }))
foreach ($n in 'RetroBar*', 'Open-Shell*', 'MPC-BE*', 'ImageGlass*') {
    $e = @(Get-UninstallEntries $n) | Select-Object -First 1
    $verLines += ('{0,-16}: {1}' -f $n.TrimEnd('*'), $(if ($e) { $e.DisplayVersion } else { '없음' }))
}
$lblVer = Add-Label $p5 ($verLines -join "`n") (New-Object Drawing.Font('Consolas', 9)) $null 6
$cbAuto = Add-Check $p5 '자동 업데이트 (Windows Update 직후, 사용 중이면 다음 부팅 때)' ([bool]$cst.AutoUpdate)
$delayPanel = New-Object Windows.Forms.FlowLayoutPanel
$delayPanel.AutoSize = $true; $delayPanel.Margin = New-Object Windows.Forms.Padding(20, 0, 3, 4)
$lblDelay = New-Object Windows.Forms.Label; $lblDelay.Text = '새 버전은 배포 후'; $lblDelay.AutoSize = $true; $lblDelay.Margin = New-Object Windows.Forms.Padding(0, 6, 3, 0)
$numDelay = New-Object Windows.Forms.NumericUpDown; $numDelay.Minimum = 0; $numDelay.Maximum = 60; $numDelay.Value = [int]$cst.DelayDays; $numDelay.Width = 50
$lblDelay2 = New-Object Windows.Forms.Label; $lblDelay2.Text = '일이 지나야 설치 (문제 있는 버전 회피)'; $lblDelay2.AutoSize = $true; $lblDelay2.Margin = New-Object Windows.Forms.Padding(3, 6, 3, 0)
$delayPanel.Controls.AddRange(@($lblDelay, $numDelay, $lblDelay2)); $p5.Controls.Add($delayPanel)
$btnCheck = New-Object Windows.Forms.Button; $btnCheck.Text = '지금 업데이트 확인'; $btnCheck.AutoSize = $true
$btnCheck.add_Click({
    Start-ScheduledTask -TaskPath '\LiteWin\' -TaskName 'LiteWin Components' -ErrorAction SilentlyContinue
    [Windows.Forms.MessageBox]::Show('백그라운드에서 확인합니다. 결과는 아래 기록과 logs\Components.log 에 남습니다.', 'LiteWin') | Out-Null
})
$p5.Controls.Add($btnCheck)
[void](Add-Label $p5 '최근 기록' $bold $null 10)
$hist = @($cst.History) | Select-Object -Last 8
[void](Add-Label $p5 $(if ($hist) { $hist -join "`n" } else { '(아직 없음)' }) $small $gray)
[void](Add-Label $p5 'Windows 정품 인증' $bold $null 12)
$actSt = Get-LWActivationStatus
$lblAct = Add-Label $p5 ("상태: {0}   {1}" -f $actSt.Text, $actSt.Key) $font $(if ($actSt.Activated) { [Drawing.Color]::SeaGreen } else { [Drawing.Color]::DarkOrange })
[void](Add-Label $p5 '    "서버에 연결할 수 없음"은 대개 시계 어긋남, 네트워크 차단, 꺼진 서비스 때문입니다. VM 은 PC 의 디지털 라이선스를 쓰지 못하니 제품 키를 넣어야 합니다.' $small $gray)
$actRow = New-Object Windows.Forms.FlowLayoutPanel; $actRow.AutoSize = $true; $actRow.WrapContents = $false
$btnActFix = New-Object Windows.Forms.Button; $btnActFix.Text = '진단 및 복구 후 인증'; $btnActFix.AutoSize = $true
$btnActKey = New-Object Windows.Forms.Button; $btnActKey.Text = '제품 키 입력…'; $btnActKey.AutoSize = $true
$actRow.Controls.AddRange(@($btnActFix, $btnActKey)); $p5.Controls.Add($actRow)
$btnActFix.add_Click({
    $form.Cursor = 'WaitCursor'
    try { $lines = Invoke-LWActivationRepair } finally { $form.Cursor = 'Default' }
    $st2 = Get-LWActivationStatus
    $lblAct.Text = "상태: $($st2.Text)   $($st2.Key)"
    [Windows.Forms.MessageBox]::Show(($lines -join "`n"), 'Windows 정품 인증 진단') | Out-Null
})
$btnActKey.add_Click({
    Add-Type -AssemblyName Microsoft.VisualBasic
    $k = [Microsoft.VisualBasic.Interaction]::InputBox('본인 Windows 11 Pro 제품 키를 입력하세요 (XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)', '제품 키 입력', '')
    if (-not $k) { return }
    $form.Cursor = 'WaitCursor'
    try { $msg = Set-LWProductKey $k } finally { $form.Cursor = 'Default' }
    $st2 = Get-LWActivationStatus
    $lblAct.Text = "상태: $($st2.Text)   $($st2.Key)"
    [Windows.Forms.MessageBox]::Show($msg, 'Windows 정품 인증') | Out-Null
})

function Save-ComponentOptions {
    $s2 = Get-LWComponentState
    $s2.AutoUpdate = $cbAuto.Checked; $s2.DelayDays = [int]$numDelay.Value
    Save-LWComponentState $s2
}

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
    $br = Get-BrowserChoices
    if (-not $br) { return }
    # 맥 입력을 새로 켤 때 한 번 알림
    if (($rbMac.Checked -or $rbUi.Checked) -and "$($state.Mode)" -notin 'MacInput', 'MacUI') {
        $msg = "맥 입력은 작은 키 매핑 프로그램(LiteWinKeys)이 보이지 않게 상주하며 키 입력을 바꿉니다.`n`n" +
               "- ⌘(왼쪽 Alt) 조합과 F열이 바뀌고, 일반 키는 그대로 통과합니다`n" +
               "- 일부 게임(특히 안티치트가 있는 게임)에서 ⌘ 조합이 막히거나, 입력 프로그램으로 감지될 수 있습니다`n" +
               "- 로그인 화면과 보안 확인(UAC) 창에서는 동작하지 않습니다`n`n" +
               "언제든 '라이트 윈도우'로 돌아가면 프로그램이 멈추고 원래 키 배치로 돌아갑니다. 켤까요?"
        if ([Windows.Forms.MessageBox]::Show($msg, '맥 입력 켜기', 'YesNo', 'Information') -ne 'Yes') { return }
    }
    if ($FirstRun) { if (-not (Invoke-AccountSetup)) { $tabs.SelectedIndex = 0; return } }
    try { Save-ComponentOptions } catch { }
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
        Keys = @{ CapsLockToHangul = $kbCaps.Checked; OptionWordMove = $kbWord.Checked; CmdQuitApp = $kbQuit.Checked
                  MacFKeys = $kbF.Checked; StandardFKeys = $kbStdF.Checked; GameAutoOff = $kbGame.Checked }
        Shell = @{ ClassicTaskbar = $shBar.Checked; ClassicStart = $shStart.Checked; TaskbarLabels = $shLabels.Checked
                   ClassicEngine = @('ep', 'retrobar')[$cbEngine.SelectedIndex]; StartEngine = @('openshell', 'ep')[$cbStart.SelectedIndex]
                   Caption = @('off', 'traffic', 'fullscreen')[$cbCaption.SelectedIndex] }
        RemoveEdge = -not $br.Edge; EdgeRedirect = $cbRedir.Checked
        Browsers = @{ Install = $br.Install; Remove = $br.Remove; Default = $br.Default }
    }
    if ($script:AdminHandoff) {
        # Administrator 로 바꾸는 경우: 선택은 저장해 두고 Administrator 첫 로그인 때 적용한다
        $pending = Join-Path $script:LWRoot 'pending-choices.json'
        $choices.HandoffFrom = $script:AdminHandoff.OldUser
        $choices | ConvertTo-Json -Depth 4 | Set-Content $pending -Encoding UTF8
        $exe = Join-Path $script:LWRoot 'bin\LiteWinSettings.exe'
        $act = New-ScheduledTaskAction -Execute $exe -Argument '-ApplyPending'
        $trg = New-ScheduledTaskTrigger -AtLogOn -User $script:AdminHandoff.Admin
        $prn = New-ScheduledTaskPrincipal -UserId $script:AdminHandoff.Admin -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskPath '\LiteWin\' -TaskName 'LiteWin Admin Handoff' -Action $act -Trigger $trg -Principal $prn -Force | Out-Null
        Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'AutoAdminLogon' '0' String
        Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'DefaultUserName' $script:AdminHandoff.Admin String
        [Windows.Forms.MessageBox]::Show("지금 로그아웃합니다. Administrator 로 로그인하면 고른 설정이 적용되고, '$($script:AdminHandoff.OldUser)' 계정이 지워집니다.", 'LiteWin') | Out-Null
        $script:LogoffAfter = $true
        $form.Close(); return
    }
    $file = Join-Path $env:TEMP ("litewin-choices-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $choices | ConvertTo-Json -Depth 4 | Set-Content $file -Encoding UTF8
    $script:PendingFile = $file
    $form.Close()
}

function Show-ApplyProgress {
    <#
        고른 내용을 이 프로세스 안에서(콘솔 창 없이) 적용하고, 진행 막대와 기록을 한 창에 보여준다.
        Apply-LiteWin.ps1 은 별도 runspace 에서 돌고, 공유 해시테이블(LWProgress)로 진행 상황을 넘긴다.
    #>
    param([string]$ChoicesFile, $Owner)
    $sync = [hashtable]::Synchronized(@{ Percent = 0; Status = '준비 중…'; Log = [Collections.ArrayList]::Synchronized((New-Object Collections.ArrayList)) })
    $iss = [Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $iss.ExecutionPolicy = [Microsoft.PowerShell.ExecutionPolicy]::Bypass
    $rs = [runspacefactory]::CreateRunspace($iss); $rs.ApartmentState = 'STA'; $rs.Open()
    $rs.SessionStateProxy.SetVariable('LWProgress', $sync)
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    [void]$ps.AddCommand((Join-Path $PSScriptRoot 'Apply-LiteWin.ps1')).AddParameter('ChoicesFile', $ChoicesFile)
    $handle = $ps.BeginInvoke()

    $pf = New-Object Windows.Forms.Form
    $pf.Text = 'LiteWin — 적용 중'; $pf.Font = $font; $pf.FormBorderStyle = 'FixedDialog'; $pf.MaximizeBox = $false; $pf.MinimizeBox = $false
    $pf.ClientSize = New-Object Drawing.Size(560, 330); $pf.StartPosition = if ($Owner) { 'CenterParent' } else { 'CenterScreen' }
    $lbl = New-Object Windows.Forms.Label; $lbl.Font = $bold; $lbl.Location = New-Object Drawing.Point(18, 16); $lbl.Size = New-Object Drawing.Size(520, 24)
    $bar = New-Object Windows.Forms.ProgressBar; $bar.Location = New-Object Drawing.Point(18, 46); $bar.Size = New-Object Drawing.Size(522, 20); $bar.Style = 'Continuous'
    $box = New-Object Windows.Forms.TextBox; $box.Multiline = $true; $box.ReadOnly = $true; $box.ScrollBars = 'Vertical'
    $box.Location = New-Object Drawing.Point(18, 78); $box.Size = New-Object Drawing.Size(522, 196); $box.BackColor = [Drawing.Color]::White
    $ok = New-Object Windows.Forms.Button; $ok.Text = '닫기'; $ok.Enabled = $false; $ok.Size = New-Object Drawing.Size(100, 30)
    $ok.Location = New-Object Drawing.Point(440, 288); $ok.add_Click({ $pf.Close() })
    $pf.Controls.AddRange(@($lbl, $bar, $box, $ok))
    $view = @{ Shown = 0 }   # 클로저 안에서 바뀌어야 하므로 해시테이블에 담는다
    $timer = New-Object Windows.Forms.Timer; $timer.Interval = 200
    $timer.add_Tick({
        $bar.Value = [int]$sync.Percent; $lbl.Text = $sync.Status
        while ($view.Shown -lt $sync.Log.Count) { $box.AppendText($sync.Log[$view.Shown] + "`r`n"); $view.Shown++ }
        if ($handle.IsCompleted) {
            $timer.Stop()
            try { $res = $ps.EndInvoke($handle) } catch { $box.AppendText("! $($_.Exception.Message)`r`n") }
            $failed = @($res | ForEach-Object { $_ } | Where-Object { $_ })
            $bar.Value = 100
            $lbl.Text = if ($failed.Count) { '완료 — 일부 항목 실패: ' + ($failed -join ', ') } else { '모두 완료되었습니다' }
            $ok.Enabled = $true; $pf.AcceptButton = $ok
            if ($FirstRun -and -not $failed.Count) {
                $auto = New-Object Windows.Forms.Timer; $auto.Interval = 2500
                $auto.add_Tick({ $auto.Stop(); $pf.Close() }.GetNewClosure()); $auto.Start()
            }
        }
    }.GetNewClosure())
    $pf.add_FormClosing({ param($s2, $e2) if (-not $handle.IsCompleted) { $e2.Cancel = $true } }.GetNewClosure())
    $timer.Start()
    if ($Owner) { [void]$pf.ShowDialog($Owner) } else { [void]$pf.ShowDialog() }
    $ps.Dispose(); $rs.Close()
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

function New-CoverImage([string]$path, [int]$w, [int]$h) {
    <# 화면 비율에 맞게 잘라 채운 배경 (늘려서 찌그러지지 않게) #>
    $src = [Drawing.Image]::FromFile($path)
    try {
        $scale = [Math]::Max($w / $src.Width, $h / $src.Height)
        $sw = [int]($w / $scale); $sh = [int]($h / $scale)
        $sx = [int](($src.Width - $sw) / 2); $sy = [int](($src.Height - $sh) / 2)
        $bmp = New-Object Drawing.Bitmap $w, $h
        $g = [Drawing.Graphics]::FromImage($bmp); $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($src, (New-Object Drawing.Rectangle 0, 0, $w, $h), (New-Object Drawing.Rectangle $sx, $sy, $sw, $sh), 'Pixel')
        $g.Dispose(); return $bmp
    } finally { $src.Dispose() }
}

if ($ApplyPending) {
    # Administrator 첫 로그인: 이전 계정 삭제 → 저장된 선택 적용 → 작업 정리
    $pending = Join-Path $script:LWRoot 'pending-choices.json'
    if (Test-Path $pending) {
        $pc = Get-Content $pending -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($pc.HandoffFrom -and $pc.HandoffFrom -ne $env:USERNAME) {
            try {
                $u = Get-LocalUser -Name $pc.HandoffFrom -ErrorAction Stop
                Get-CimInstance Win32_UserProfile | Where-Object { $_.SID -eq $u.SID.Value } | Remove-CimInstance -ErrorAction SilentlyContinue
                Remove-LocalUser -Name $pc.HandoffFrom -ErrorAction Stop
                Write-LWLog "이전 계정 '$($pc.HandoffFrom)' 삭제 (Administrator 하나만 사용)"
            } catch { Write-LWLog "이전 계정 삭제 실패: $_" WARN }
        }
        $file = Join-Path $env:TEMP 'litewin-pending.json'
        Copy-Item $pending $file -Force; Remove-Item $pending -Force
        $FirstRun = $true
        Show-ApplyProgress -ChoicesFile $file
    }
    Unregister-ScheduledTask -TaskPath '\LiteWin\' -TaskName 'LiteWin Admin Handoff' -Confirm:$false -ErrorAction SilentlyContinue
    return
}

if ($FirstRun) {
    # 첫 로그인: 설치의 마지막 단계처럼 전체 화면 배경 위에서 묻는다. 적용이 끝나면 바탕화면이 나온다.
    $screen = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $light = $true
    $pers = Get-RegValueEntry -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme'
    if ($pers -and [int]$pers.Value -eq 0) { $light = $false }
    $back = New-Object Windows.Forms.Form
    $back.FormBorderStyle = 'None'; $back.StartPosition = 'Manual'; $back.Bounds = $screen
    $back.ShowInTaskbar = $false; $back.AutoScaleMode = 'None'
    $back.BackColor = if ($light) { [Drawing.Color]::FromArgb(236, 234, 231) } else { [Drawing.Color]::FromArgb(43, 47, 56) }
    $img = Join-Path $env:WINDIR ('Web\Wallpaper\LiteWin\wave_{0}.jpg' -f $(if ($light) { 'light' } else { 'dark' }))
    if (Test-Path $img) { try { $back.BackgroundImage = New-CoverImage $img $screen.Width $screen.Height; $back.BackgroundImageLayout = 'None' } catch { } }
    $fg  = if ($light) { [Drawing.Color]::FromArgb(32, 33, 36) } else { [Drawing.Color]::White }
    $fg2 = if ($light) { [Drawing.Color]::FromArgb(80, 82, 88) } else { [Drawing.Color]::Gainsboro }

    # 글자 크기와 위치를 화면 높이에 비례해서 정하고, 설정 창은 제목 아래 가운데에 둔다 (겹치지 않게)
    $titleSize = [Math]::Max(16, [Math]::Min(30, [int]($screen.Height / 40)))
    $title = New-Object Windows.Forms.Label
    $title.Text = 'LiteWin 설정을 마무리합니다'; $title.AutoSize = $true; $title.BackColor = [Drawing.Color]::Transparent
    $title.ForeColor = $fg; $title.Font = New-Object Drawing.Font('Malgun Gothic', $titleSize, [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
    $sub = New-Object Windows.Forms.Label
    $sub.Text = '원하는 방식을 고르세요. 나중에 시작 메뉴 > LiteWin 설정 에서 언제든 바꿀 수 있습니다.'; $sub.AutoSize = $true
    $sub.BackColor = [Drawing.Color]::Transparent; $sub.ForeColor = $fg2
    $sub.Font = New-Object Drawing.Font('Malgun Gothic', [Math]::Max(12, [int]($titleSize * 0.55)), [Drawing.FontStyle]::Regular, [Drawing.GraphicsUnit]::Pixel)
    $back.Controls.AddRange(@($title, $sub))
    $layout = {
        $top = [int]($screen.Height * 0.06)
        $title.Location = New-Object Drawing.Point([int](($screen.Width - $title.PreferredWidth) / 2), $top)
        $sub.Location = New-Object Drawing.Point([int](($screen.Width - $sub.PreferredWidth) / 2), $top + $title.PreferredHeight + 6)
        $formTop = $sub.Bottom + [int]($screen.Height * 0.03)
        if ($formTop + $form.Height -gt $screen.Height - 10) { $formTop = [Math]::Max($sub.Bottom + 6, $screen.Height - $form.Height - 10) }
        $form.StartPosition = 'Manual'
        $form.Location = New-Object Drawing.Point([int]($screen.X + ($screen.Width - $form.Width) / 2), [int]($screen.Y + $formTop))
    }
    $back.Show(); & $layout
    [void]$form.ShowDialog($back)
    if ($script:PendingFile) {
        $title.Text = '적용하는 중입니다…'; $sub.Text = '끝나면 바탕화면이 나타납니다.'
        & $layout
        Show-ApplyProgress -ChoicesFile $script:PendingFile -Owner $back
    }
    $back.Close()
    if ($script:LogoffAfter) { & "$env:WINDIR\System32\shutdown.exe" /l }
} else {
    [void]$form.ShowDialog()
    if ($script:PendingFile) { Show-ApplyProgress -ChoicesFile $script:PendingFile }
}
