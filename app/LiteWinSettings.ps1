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
. (Join-Path $root 'lib\LiteWin.Components.ps1')
. (Join-Path $root 'lib\LiteWin.Browsers.ps1')

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

    [void](Add-Label $p0 '고급' $bold $null 14)
    $cbAdmin = Add-Check $p0 '기본 제공 Administrator 계정도 사용' $false 12
    [void](Add-Label $p0 '    Windows 에 숨겨져 있는 최고 권한 계정을 켭니다. 일반적인 사용에는 필요 없습니다.' $small $gray)
    $txtAdm  = New-TextRow $p0 'Administrator 암호' -Password
    $txtAdm2 = New-TextRow $p0 '암호 확인' -Password
    $txtAdm.Enabled = $false; $txtAdm2.Enabled = $false
    $script:adminConfirmed = $false
    $cbAdmin.add_CheckedChanged({
        if ($cbAdmin.Checked -and -not $script:adminConfirmed) {
            $m1 = "기본 제공 Administrator 계정은 사용자 계정 컨트롤(UAC) 확인 없이 모든 프로그램이 최고 권한으로 실행됩니다.`n`n" +
                  "- 악성 프로그램이 확인 창 없이 시스템 전체를 바꿀 수 있습니다`n- 실수로 시스템 파일을 지워도 막아 주지 않습니다`n- 일부 Store 앱과 보안 기능이 제한될 수 있습니다`n`n계속할까요?"
            $r1 = [Windows.Forms.MessageBox]::Show($m1, '보안 경고', 'YesNo', 'Warning', 'Button2')
            $r2 = 'No'
            if ($r1 -eq 'Yes') {
                $r2 = [Windows.Forms.MessageBox]::Show("한 번 더 확인합니다.`n`nAdministrator 계정을 켜고, 반드시 암호를 정해야 합니다. 평소에는 위의 일반 계정을 쓰고, 필요할 때만 Administrator 로 로그인하는 것을 권장합니다.`n`n정말 켤까요?", '보안 경고 (2/2)', 'YesNo', 'Warning', 'Button2')
            }
            if ($r2 -ne 'Yes') { $cbAdmin.Checked = $false; return }
            $script:adminConfirmed = $true
        }
        $txtAdm.Enabled = $cbAdmin.Checked; $txtAdm2.Enabled = $cbAdmin.Checked
    })

    function Invoke-AccountSetup {
        <# 창에서 바로 처리한다 (암호를 파일에 남기지 않기 위해). 실패하면 $false #>
        $name = $txtName.Text.Trim()
        if (-not $name) { $name = 'user' }
        if ($name.Length -gt 20 -or $name -match '["/\\\[\]:;|=,+*?<>@]') {
            [Windows.Forms.MessageBox]::Show('이름은 20자 이하이고 " / \ [ ] : ; | = , + * ? < > @ 를 쓸 수 없습니다.', 'LiteWin') | Out-Null; return $false
        }
        if ($txtPw.Text -ne $txtPw2.Text) { [Windows.Forms.MessageBox]::Show('암호가 서로 다릅니다.', 'LiteWin') | Out-Null; return $false }
        if ($cbAdmin.Checked) {
            if (-not $txtAdm.Text) { [Windows.Forms.MessageBox]::Show('Administrator 계정에는 암호가 꼭 필요합니다.', 'LiteWin') | Out-Null; return $false }
            if ($txtAdm.Text -ne $txtAdm2.Text) { [Windows.Forms.MessageBox]::Show('Administrator 암호가 서로 다릅니다.', 'LiteWin') | Out-Null; return $false }
        }
        try {
            $me = $env:USERNAME
            if ($name -ne $me) { Rename-LocalUser -Name $me -NewName $name -ErrorAction Stop }
            Set-LocalUser -Name $name -FullName $name -ErrorAction SilentlyContinue
            if ($txtPw.Text) { Set-LocalUser -Name $name -Password (ConvertTo-SecureString $txtPw.Text -AsPlainText -Force) -ErrorAction Stop }
            if ($cbAdmin.Checked) {
                $adm = Get-LocalUser | Where-Object { $_.SID.Value -like 'S-1-5-*-500' } | Select-Object -First 1
                Set-LocalUser -SID $adm.SID -Password (ConvertTo-SecureString $txtAdm.Text -AsPlainText -Force) -ErrorAction Stop
                Enable-LocalUser -SID $adm.SID -ErrorAction Stop
                Write-LWLog "기본 제공 Administrator 계정 켬 (사용자 확인 2회)" WARN
            }
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
    if ($acct -or $FirstRun) { if (-not (Invoke-AccountSetup)) { $tabs.SelectedIndex = 0; return } }
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
    $file = Join-Path $env:TEMP ("litewin-choices-{0}.json" -f [guid]::NewGuid().ToString('N'))
    $choices | ConvertTo-Json -Depth 4 | Set-Content $file -Encoding UTF8
    $script:ApplyProc = Start-Process powershell.exe -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
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

if ($FirstRun) {
    # 첫 로그인: 설치의 마지막 단계처럼 전체 화면 배경 위에서 묻는다. 적용이 끝나면 바탕화면이 나온다.
    $screen = [Windows.Forms.Screen]::PrimaryScreen.Bounds
    $back = New-Object Windows.Forms.Form
    $back.FormBorderStyle = 'None'; $back.StartPosition = 'Manual'; $back.Bounds = $screen
    $back.ShowInTaskbar = $false; $back.BackColor = [Drawing.Color]::FromArgb(43, 47, 56)
    $img = Join-Path $env:WINDIR 'Web\Wallpaper\LiteWin\wave_dark.jpg'
    if (Test-Path $img) { try { $back.BackgroundImage = [Drawing.Image]::FromFile($img); $back.BackgroundImageLayout = 'Stretch' } catch { } }
    $title = New-Object Windows.Forms.Label
    $title.Text = 'LiteWin 설정을 마무리합니다'; $title.AutoSize = $true; $title.BackColor = [Drawing.Color]::Transparent
    $title.ForeColor = [Drawing.Color]::White; $title.Font = New-Object Drawing.Font('Malgun Gothic', 22)
    $title.Location = New-Object Drawing.Point(60, 50)
    $sub = New-Object Windows.Forms.Label
    $sub.Text = '원하는 방식을 고르세요. 나중에 시작 메뉴 > LiteWin 설정 에서 언제든 바꿀 수 있습니다.'; $sub.AutoSize = $true
    $sub.BackColor = [Drawing.Color]::Transparent; $sub.ForeColor = [Drawing.Color]::Gainsboro
    $sub.Font = New-Object Drawing.Font('Malgun Gothic', 11); $sub.Location = New-Object Drawing.Point(64, 105)
    $back.Controls.AddRange(@($title, $sub))
    $back.Show()
    $form.StartPosition = 'CenterParent'
    [void]$form.ShowDialog($back)
    if ($script:ApplyProc) {
        $title.Text = '적용하는 중입니다…'; $sub.Text = '끝나면 바탕화면이 나타납니다. 진행 상황은 가운데 창에 표시됩니다.'
        while (-not $script:ApplyProc.HasExited) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
    }
    $back.Close()
} else {
    [void]$form.ShowDialog()
}
