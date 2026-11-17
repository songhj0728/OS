<#
    LiteWin 설정 > 계정 > [계정 설정…] 팝업
    ┌──────────────────────────────────────────┐
    │ (그림) user                    관리자     │
    │ (그림) 동생                    표준·새 계정│
    ├──────────────────────────────────────────┤
    │ [사용자 추가] [수정]          [적용] [닫기]│
    └──────────────────────────────────────────┘
    - 수정: 암호가 있는 계정은 현재 암호 확인 → 이름·암호 바꾸기 → 마칠 때 기존 암호 한 번 더 확인
    - 바뀐 내용은 [적용] 을 눌러야 실제로 바뀐다. 적용하지 않고 닫으면 경고.
#>
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\LiteWin.Accounts.ps1')

function New-LWRoundIcon([string]$Path, [string]$Name, [int]$Size = 48) {
    <# 프로필 그림을 동그랗게 (없으면 이름 첫 글자) #>
    $bmp = New-Object Drawing.Bitmap $Size, $Size
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
    $clip = New-Object Drawing.Drawing2D.GraphicsPath
    $clip.AddEllipse(1, 1, $Size - 2, $Size - 2)
    $drawn = $false
    if ($Path -and (Test-Path $Path)) {
        try {
            $ms = New-Object IO.MemoryStream (, [IO.File]::ReadAllBytes($Path))   # 파일을 잠그지 않게
            $img = [Drawing.Image]::FromStream($ms)
            $g.SetClip($clip); $g.DrawImage($img, 0, 0, $Size, $Size); $g.ResetClip()
            $img.Dispose(); $ms.Dispose(); $drawn = $true
        } catch { }
    }
    if (-not $drawn) {
        $g.FillPath((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(120, 130, 145))), $clip)
        $ch = if ($Name) { $Name.Substring(0, 1).ToUpper() } else { '?' }
        $f = New-Object Drawing.Font('Malgun Gothic', [float]($Size * 0.38), [Drawing.FontStyle]::Bold, [Drawing.GraphicsUnit]::Pixel)
        $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
        $g.DrawString($ch, $f, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF 0, 0, $Size, $Size), $sf)
    }
    $g.Dispose(); return $bmp
}

function Read-LWPassword([string]$Title, [string]$Message, $Owner) {
    <# 암호 한 칸 입력 창. 취소하면 $null #>
    $f = New-Object Windows.Forms.Form
    $f.Text = $Title; $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'; $f.ClientSize = New-Object Drawing.Size(380, 140); $f.Font = New-Object Drawing.Font('Malgun Gothic', 9)
    $l = New-Object Windows.Forms.Label; $l.Text = $Message; $l.Location = New-Object Drawing.Point(14, 12); $l.Size = New-Object Drawing.Size(352, 40)
    $t = New-Object Windows.Forms.TextBox; $t.UseSystemPasswordChar = $true; $t.Location = New-Object Drawing.Point(16, 58); $t.Width = 348
    $ok = New-Object Windows.Forms.Button; $ok.Text = '확인'; $ok.DialogResult = 'OK'; $ok.Location = New-Object Drawing.Point(196, 98); $ok.Size = New-Object Drawing.Size(80, 28)
    $no = New-Object Windows.Forms.Button; $no.Text = '취소'; $no.DialogResult = 'Cancel'; $no.Location = New-Object Drawing.Point(284, 98); $no.Size = New-Object Drawing.Size(80, 28)
    $f.Controls.AddRange(@($l, $t, $ok, $no)); $f.AcceptButton = $ok; $f.CancelButton = $no
    $r = $f.ShowDialog($Owner); $v = $t.Text; $f.Dispose()
    if ($r -ne 'OK') { return $null }
    return $v
}

function Show-LWProfileDialog {
    <#
        이름·암호 설정 창. $Account 가 없으면 새 계정.
        .OUTPUTS @{ Name; ChangePassword; Password; Admin } 또는 $null(취소)
    #>
    param($Account, [string[]]$TakenNames, $Owner)
    $isNew = -not $Account
    $f = New-Object Windows.Forms.Form
    $f.Text = if ($isNew) { '사용자 추가' } else { "프로필 옵션 — $($Account.DisplayName)" }
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition = 'CenterParent'; $f.ClientSize = New-Object Drawing.Size(400, 270); $f.Font = New-Object Drawing.Font('Malgun Gothic', 9)
    $y = 16
    $mk = {
        param([string]$label, [switch]$Pw)
        $l = New-Object Windows.Forms.Label; $l.Text = $label; $l.Location = New-Object Drawing.Point(16, ($y + 4)); $l.AutoSize = $true
        $t = New-Object Windows.Forms.TextBox; $t.Location = New-Object Drawing.Point(130, $y); $t.Width = 250
        if ($Pw) { $t.UseSystemPasswordChar = $true }
        $f.Controls.AddRange(@($l, $t)); return $t
    }
    $tName = & $mk '사용자 이름'; $y += 36
    if (-not $isNew) { $tName.Text = $Account.DisplayName }
    $tPw = & $mk $(if ($isNew) { '암호 (선택)' } else { '새 암호' }) -Pw; $y += 32
    $tPw2 = & $mk '암호 확인' -Pw; $y += 32
    $hint = New-Object Windows.Forms.Label; $hint.ForeColor = [Drawing.Color]::DimGray; $hint.Location = New-Object Drawing.Point(130, $y); $hint.Size = New-Object Drawing.Size(250, 34)
    $hint.Text = if ($isNew) { '암호를 비워 두면 암호 없이 로그인합니다.' } else { '암호 칸을 비워 두면 지금 암호를 그대로 둡니다.' }
    $f.Controls.Add($hint); $y += 38
    $cbNoPw = $null; $cbAdmin = $null
    if (-not $isNew -and $Account.HasPassword) {
        $cbNoPw = New-Object Windows.Forms.CheckBox; $cbNoPw.Text = '암호 없애기 (암호 없이 로그인)'; $cbNoPw.AutoSize = $true
        $cbNoPw.Location = New-Object Drawing.Point(130, $y); $f.Controls.Add($cbNoPw); $y += 28
        $cbNoPw.add_CheckedChanged({ $tPw.Enabled = -not $cbNoPw.Checked; $tPw2.Enabled = -not $cbNoPw.Checked })
    }
    if ($isNew) {
        $cbAdmin = New-Object Windows.Forms.CheckBox; $cbAdmin.Text = '관리자 권한 (프로그램 설치 등)'; $cbAdmin.Checked = $true; $cbAdmin.AutoSize = $true
        $cbAdmin.Location = New-Object Drawing.Point(130, $y); $f.Controls.Add($cbAdmin); $y += 28
    }
    $ok = New-Object Windows.Forms.Button; $ok.Text = $(if ($isNew) { '추가' } else { '수정 완료' }); $ok.Location = New-Object Drawing.Point(206, 228); $ok.Size = New-Object Drawing.Size(88, 30)
    $no = New-Object Windows.Forms.Button; $no.Text = '취소'; $no.DialogResult = 'Cancel'; $no.Location = New-Object Drawing.Point(300, 228); $no.Size = New-Object Drawing.Size(80, 30)
    $f.Controls.AddRange(@($ok, $no)); $f.AcceptButton = $ok; $f.CancelButton = $no
    $ok.add_Click({
        $n = $tName.Text.Trim()
        $why = Test-LWAccountName $n
        if (-not $why -and ($TakenNames | Where-Object { $_ -eq $n })) { $why = "'$n' 계정이 이미 있습니다." }
        if ($why) { [Windows.Forms.MessageBox]::Show($why, '계정 설정') | Out-Null; return }
        $noPw = $cbNoPw -and $cbNoPw.Checked
        if (-not $noPw -and $tPw.Text -ne $tPw2.Text) { [Windows.Forms.MessageBox]::Show('암호가 서로 다릅니다.', '계정 설정') | Out-Null; return }
        $f.DialogResult = 'OK'
    })
    $r = $f.ShowDialog($Owner)
    $res = $null
    if ($r -eq 'OK') {
        $noPw = $cbNoPw -and $cbNoPw.Checked
        $res = @{
            Name = $tName.Text.Trim()
            ChangePassword = $isNew -or $noPw -or [bool]$tPw.Text
            Password = if ($noPw) { '' } else { $tPw.Text }
            Admin = if ($cbAdmin) { $cbAdmin.Checked } else { $null }
        }
    }
    $f.Dispose()
    return $res
}

function Show-LWAccountManager {
    param($Owner)
    $st = @{ Items = New-Object Collections.ArrayList; Dirty = $false }
    $load = {
        $st.Items.Clear()
        foreach ($a in @(Get-LWLocalAccounts)) {
            [void]$st.Items.Add(@{ Name = $a.Name; DisplayName = $a.Name; Sid = $a.Sid; IsAdmin = $a.IsAdmin; IsCurrent = $a.IsCurrent
                                   IsBuiltinAdmin = $a.IsBuiltinAdmin; HasPassword = $a.HasPassword; Picture = $a.Picture
                                   IsNew = $false; Changed = $false; NewPassword = $null })
        }
        $st.Dirty = $false
    }
    & $load

    $f = New-Object Windows.Forms.Form
    $f.Text = '계정 설정'; $f.StartPosition = 'CenterParent'; $f.ClientSize = New-Object Drawing.Size(520, 440)
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.Font = New-Object Drawing.Font('Malgun Gothic', 9)
    $lv = New-Object Windows.Forms.ListView
    $lv.View = 'Details'; $lv.HeaderStyle = 'None'; $lv.FullRowSelect = $true; $lv.MultiSelect = $false; $lv.HideSelection = $false
    $lv.Location = New-Object Drawing.Point(12, 12); $lv.Size = New-Object Drawing.Size(496, 370)
    $lv.Font = New-Object Drawing.Font('Malgun Gothic', 11)
    [void]$lv.Columns.Add('이름', 330, 'Left'); [void]$lv.Columns.Add('상태', 140, 'Right')
    $il = New-Object Windows.Forms.ImageList; $il.ImageSize = New-Object Drawing.Size(48, 48); $il.ColorDepth = 'Depth32Bit'
    $lv.SmallImageList = $il
    $bAdd  = New-Object Windows.Forms.Button; $bAdd.Text = '사용자 추가'; $bAdd.Location = New-Object Drawing.Point(12, 396); $bAdd.Size = New-Object Drawing.Size(100, 32)
    $bEdit = New-Object Windows.Forms.Button; $bEdit.Text = '수정'; $bEdit.Location = New-Object Drawing.Point(118, 396); $bEdit.Size = New-Object Drawing.Size(80, 32); $bEdit.Enabled = $false
    $bApply = New-Object Windows.Forms.Button; $bApply.Text = '적용'; $bApply.Location = New-Object Drawing.Point(342, 396); $bApply.Size = New-Object Drawing.Size(80, 32); $bApply.Enabled = $false
    $bClose = New-Object Windows.Forms.Button; $bClose.Text = '닫기'; $bClose.Location = New-Object Drawing.Point(428, 396); $bClose.Size = New-Object Drawing.Size(80, 32)
    $f.Controls.AddRange(@($lv, $bAdd, $bEdit, $bApply, $bClose)); $f.CancelButton = $bClose

    $refresh = {
        $lv.BeginUpdate(); $lv.Items.Clear(); $il.Images.Clear()
        for ($i = 0; $i -lt $st.Items.Count; $i++) {
            $a = $st.Items[$i]
            $il.Images.Add((New-LWRoundIcon $a.Picture $a.DisplayName 48))
            $it = New-Object Windows.Forms.ListViewItem ($a.DisplayName, $i)
            $it.UseItemStyleForSubItems = $false
            $tags = @()
            if ($a.IsBuiltinAdmin) { $tags += 'Administrator' } elseif ($a.IsAdmin) { $tags += '관리자' } else { $tags += '표준' }
            if ($a.IsCurrent) { $tags += '현재' }
            if ($a.IsNew) { $tags += '새 계정' } elseif ($a.Changed) { $tags += '변경됨' }
            $sub = $it.SubItems.Add(($tags -join ' · ')); $sub.ForeColor = [Drawing.Color]::DimGray
            $sub.Font = New-Object Drawing.Font('Malgun Gothic', 9)
            $it.Tag = $i
            [void]$lv.Items.Add($it)
        }
        $lv.EndUpdate()
        $bEdit.Enabled = $lv.SelectedItems.Count -gt 0
        $bApply.Enabled = $st.Dirty
    }
    $taken = { param($except) @($st.Items | Where-Object { -not [object]::ReferenceEquals($_, $except) } | ForEach-Object { $_.DisplayName; $_.Name }) }

    $lv.add_SelectedIndexChanged({ $bEdit.Enabled = $lv.SelectedItems.Count -gt 0 })
    $lv.add_DoubleClick({ if ($bEdit.Enabled) { $bEdit.PerformClick() } })
    $bAdd.add_Click({
        $r = Show-LWProfileDialog -Account $null -TakenNames (& $taken $null) -Owner $f
        if (-not $r) { return }
        [void]$st.Items.Add(@{ Name = $r.Name; DisplayName = $r.Name; Sid = ''; IsAdmin = [bool]$r.Admin; IsCurrent = $false; IsBuiltinAdmin = $false
                               HasPassword = [bool]$r.Password; Picture = (Get-LWAccountPicture ''); IsNew = $true; Changed = $true; NewPassword = $r.Password })
        $st.Dirty = $true; & $refresh
    })
    $bEdit.add_Click({
        if ($lv.SelectedItems.Count -eq 0) { return }
        $a = $st.Items[[int]$lv.SelectedItems[0].Tag]
        $verify = (-not $a.IsNew) -and $a.HasPassword
        if ($verify) {
            $p = Read-LWPassword '현재 암호 확인' "'$($a.Name)' 계정을 수정하려면 현재 암호를 입력하세요." $f
            if ($null -eq $p) { return }
            if (-not (Test-LWPassword -Name $a.Name -Password $p)) { [Windows.Forms.MessageBox]::Show('암호가 맞지 않습니다.', '계정 설정', 'OK', 'Warning') | Out-Null; return }
        }
        $r = Show-LWProfileDialog -Account $a -TakenNames (& $taken $a) -Owner $f
        if (-not $r) { return }
        if ($verify) {
            $p = Read-LWPassword '변경 확인' '수정을 마치려면 기존 암호를 한 번 더 입력하세요.' $f
            if ($null -eq $p) { return }
            if (-not (Test-LWPassword -Name $a.Name -Password $p)) { [Windows.Forms.MessageBox]::Show('암호가 맞지 않아 수정하지 않았습니다.', '계정 설정', 'OK', 'Warning') | Out-Null; return }
        }
        if ($r.Name -ne $a.DisplayName) { $a.DisplayName = $r.Name; $a.Changed = $true }
        if ($r.ChangePassword) { $a.NewPassword = $r.Password; $a.Changed = $true }
        if ($a.Changed) { $st.Dirty = $true }
        & $refresh
    })
    $bApply.add_Click({
        $f.Cursor = 'WaitCursor'; $bApply.Text = '적용 중…'; $f.Refresh()
        $done = @(); $fail = @(); $relog = $false
        foreach ($a in @($st.Items | Where-Object { $_.Changed })) {
            try {
                if ($a.IsNew) {
                    New-LWAccount -Name $a.DisplayName -Password "$($a.NewPassword)" -Admin $a.IsAdmin
                    $done += "새 계정 '$($a.DisplayName)'"
                    continue
                }
                if ($null -ne $a.NewPassword) {
                    Set-LWAccountPassword -Name $a.Name -Password $a.NewPassword
                    $done += "'$($a.Name)' 암호 $(if ($a.NewPassword) { '변경' } else { '없앰' })"
                }
                if ($a.DisplayName -ne $a.Name) {
                    Rename-LocalUser -SID $a.Sid -NewName $a.DisplayName -ErrorAction Stop
                    Set-LocalUser -SID $a.Sid -FullName $a.DisplayName -ErrorAction SilentlyContinue
                    $wl = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
                    if ((Get-ItemProperty $wl -ErrorAction SilentlyContinue).DefaultUserName -eq $a.Name) { Set-RegValue $wl 'DefaultUserName' $a.DisplayName String }
                    $done += "'$($a.Name)' → '$($a.DisplayName)'"
                    if ($a.IsCurrent) { $relog = $true }
                }
            } catch { $fail += "$($a.DisplayName): $($_.Exception.Message)" }
        }
        foreach ($d in $done) { Write-LWLog "계정 설정: $d" }
        foreach ($x in $fail) { Write-LWLog "계정 설정 실패: $x" WARN }
        & $load; & $refresh
        $f.Cursor = 'Default'; $bApply.Text = '적용'
        $msg = if ($done) { "적용했습니다.`n- " + ($done -join "`n- ") } else { '바뀐 내용이 없습니다.' }
        if ($fail) { $msg += "`n`n실패:`n- " + ($fail -join "`n- ") }
        if ($relog) { $msg += "`n`n지금 계정의 이름은 로그아웃 후 다시 로그인하면 화면에 반영됩니다. (사용자 폴더 이름은 바뀌지 않습니다)" }
        [Windows.Forms.MessageBox]::Show($msg, '계정 설정', 'OK', $(if ($fail) { 'Warning' } else { 'Information' })) | Out-Null
    })
    $bClose.add_Click({ $f.Close() })
    $f.add_FormClosing({
        param($s, $e)
        if ($st.Dirty) {
            $r = [Windows.Forms.MessageBox]::Show('저장하지 않은 변경사항이 있습니다. 닫으시겠습니까?', '계정 설정', 'OKCancel', 'Warning', 'Button2')
            if ($r -ne 'OK') { $e.Cancel = $true }
        }
    })
    & $refresh
    [void]$f.ShowDialog($Owner)
    $f.Dispose()
}
