<#
    로컬 계정 관리 (LiteWin 설정 > 계정 > 계정 설정, 첫 로그인 마법사)
    - 목록: 사용 중인 로컬 계정 + 프로필 그림
    - 암호 확인: Windows 로그온 API 로 검사 (암호를 저장하지 않음)
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

if (-not ('LiteWin.Logon' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace LiteWin {
    public static class Logon {
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        static extern bool LogonUser(string user, string domain, string password, int type, int provider, out IntPtr token);
        [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr h);
        // 0 = 맞음, 1326 = 틀림. 암호는 맞지만 다른 제한으로 막힌 경우:
        // 1327 빈 암호 제한, 1330 암호 만료, 1385 이 방식 로그온 권한 없음, 1907 다음 로그온 때 암호 변경 필요
        public static int Check(string user, string password, int type) {
            IntPtr t;
            if (LogonUser(user, ".", password ?? "", type, 0, out t)) { CloseHandle(t); return 0; }
            return Marshal.GetLastWin32Error();
        }
    }
}
'@
}

$script:HiddenAccounts = 'DefaultAccount', 'Guest', 'WDAGUtilityAccount', 'defaultuser0'

function Test-LWPassword {
    <# 이 암호가 맞으면 $true (빈 암호 계정에 빈 문자열을 넣으면 $true) #>
    param([Parameter(Mandatory)][string]$Name, [string]$Password = '')
    $r = [LiteWin.Logon]::Check($Name, $Password, 3)            # 네트워크 로그온(가벼움)
    # 이 코드들은 Windows 가 암호를 확인한 뒤에만 돌려준다 → 암호는 맞음
    return ($r -in 0, 1327, 1330, 1385, 1907)
}

function Test-LWHasPassword([string]$Name) { -not (Test-LWPassword -Name $Name -Password '') }

function Get-LWAccountPicture([string]$Sid) {
    <# 계정 그림 파일 경로 (없으면 Windows 기본 그림) #>
    $k = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$Sid"
    $p = Get-ItemProperty $k -ErrorAction SilentlyContinue
    foreach ($n in 'Image96', 'Image64', 'Image48', 'Image192', 'Image208', 'Image240') {
        if ($p -and $p.$n -and (Test-Path $p.$n)) { return $p.$n }
    }
    foreach ($f in 'user-48.png', 'user.png', 'user-192.png') {
        $d = Join-Path $env:ProgramData "Microsoft\User Account Pictures\$f"
        if (Test-Path $d) { return $d }
    }
    return $null
}

function Get-LWLocalAccounts {
    <# 사용 중인 로컬 계정 목록 #>
    $admins = @()
    try { $admins = @(Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop | ForEach-Object { "$($_.SID)" }) } catch { }
    foreach ($u in Get-LocalUser) {
        if (-not $u.Enabled -or $script:HiddenAccounts -contains $u.Name) { continue }
        $sid = "$($u.SID)"
        [pscustomobject]@{
            Name = $u.Name; Sid = $sid; FullName = $u.FullName
            IsAdmin = $admins -contains $sid; IsBuiltinAdmin = $sid -like 'S-1-5-*-500'
            IsCurrent = $sid -eq [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
            HasPassword = Test-LWHasPassword $u.Name
            Picture = Get-LWAccountPicture $sid
        }
    }
}

function Test-LWAccountName([string]$Name) {
    <# 쓸 수 있는 이름이면 $null, 아니면 이유 #>
    if (-not $Name) { return '이름을 입력하세요.' }
    if ($Name.Length -gt 20) { return '이름은 20자 이하여야 합니다.' }
    if ($Name -match '["/\\\[\]:;|=,+*?<>@]' -or $Name -match '^[\. ]+$') { return '이름에 " / \ [ ] : ; | = , + * ? < > @ 를 쓸 수 없습니다.' }
    if ($script:HiddenAccounts -contains $Name -or $Name -eq 'Administrator') { return "'$Name' 은(는) Windows 가 쓰는 이름입니다." }
    return $null
}

function Set-LWAccountPassword {
    <# 암호 설정 (빈 문자열이면 암호 없애기) #>
    param([Parameter(Mandatory)][string]$Name, [string]$Password = '')
    $u = [ADSI]"WinNT://$env:COMPUTERNAME/$Name,user"
    $u.SetPassword($Password)
    $u.SetInfo()
}

function New-LWAccount {
    param([Parameter(Mandatory)][string]$Name, [string]$Password = '', [bool]$Admin = $true)
    if ($Password) { New-LocalUser -Name $Name -FullName $Name -Password (ConvertTo-SecureString $Password -AsPlainText -Force) -PasswordNeverExpires -AccountNeverExpires -ErrorAction Stop | Out-Null }
    else { New-LocalUser -Name $Name -FullName $Name -NoPassword -AccountNeverExpires -ErrorAction Stop | Out-Null }
    $grp = if ($Admin) { 'S-1-5-32-544' } else { 'S-1-5-32-545' }   # Administrators / Users (언어와 무관)
    Add-LocalGroupMember -SID $grp -Member $Name -ErrorAction SilentlyContinue
    if ($Admin) { Add-LocalGroupMember -SID 'S-1-5-32-545' -Member $Name -ErrorAction SilentlyContinue }
    # '다음 로그온 때 암호 변경' 표시가 붙지 않게
    try { $u = [ADSI]"WinNT://$env:COMPUTERNAME/$Name,user"; $u.PasswordExpired = 0; $u.SetInfo() } catch { }
}
