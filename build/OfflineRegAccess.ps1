<#
    오프라인 하이브의 보호된 키(TrustedInstaller 소유 등)에 쓰기 위한 도우미.
    관리자라도 일부 키는 권한이 없어 '액세스 거부'가 난다. 이때:
      1) 소유권 가져오기/복원 권한(SeTakeOwnership, SeRestore, SeBackup)을 켜고
      2) 키 소유자를 Administrators 로 바꾼 뒤 Administrators 에 모든 권한을 준다.
    그래도 안 되면 호출한 쪽에서 해당 값만 건너뛰고 경고를 남긴다.
    (설치 이미지 안의 레지스트리만 바꾼다. 빌드하는 PC 의 레지스트리는 건드리지 않는다.)
#>

if (-not ('LiteWin.TokenPrivilege' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace LiteWin {
    public static class TokenPrivilege {
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        struct TOKEN_PRIVILEGES { public int Count; public long Luid; public int Attr; }
        [DllImport("advapi32.dll", SetLastError = true)] static extern bool OpenProcessToken(IntPtr h, int acc, out IntPtr tok);
        [DllImport("advapi32.dll", SetLastError = true)] static extern bool LookupPrivilegeValue(string host, string name, out long luid);
        [DllImport("advapi32.dll", SetLastError = true)] static extern bool AdjustTokenPrivileges(IntPtr tok, bool disableAll, ref TOKEN_PRIVILEGES n, int len, IntPtr prev, IntPtr rel);
        [DllImport("kernel32.dll")] static extern IntPtr GetCurrentProcess();
        public static bool Enable(string name) {
            IntPtr tok;
            if (!OpenProcessToken(GetCurrentProcess(), 0x20 | 0x8, out tok)) return false;   // ADJUST_PRIVILEGES | QUERY
            TOKEN_PRIVILEGES tp = new TOKEN_PRIVILEGES();
            tp.Count = 1; tp.Attr = 2;                                                        // SE_PRIVILEGE_ENABLED
            if (!LookupPrivilegeValue(null, name, out tp.Luid)) return false;
            return AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero) && Marshal.GetLastWin32Error() == 0;
        }
    }
}
'@
}

$script:RegPrivilegesEnabled = $false
function Enable-RegTakeOwnership {
    if ($script:RegPrivilegesEnabled) { return }
    foreach ($p in 'SeTakeOwnershipPrivilege', 'SeRestorePrivilege', 'SeBackupPrivilege') { [void][LiteWin.TokenPrivilege]::Enable($p) }
    $script:RegPrivilegesEnabled = $true
}

function Grant-OfflineKeyAccess {
    <#
        .PARAMETER SubKey  HKLM 아래 경로 (예: LW_SYSTEM\ControlSet001\Services\DiagTrack). 없으면 가장 가까운 상위 키에 권한을 준다.
        .OUTPUTS 성공하면 $true
    #>
    param([Parameter(Mandatory)][string]$SubKey)
    Enable-RegTakeOwnership
    $admins = New-Object System.Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $path = $SubKey.TrimEnd('\')
    # 존재하는 가장 가까운 키를 찾는다 (새 키를 만들려면 부모에 권한이 필요)
    while ($path -and -not (Test-Path -LiteralPath "Registry::HKEY_LOCAL_MACHINE\$path")) {
        $i = $path.LastIndexOf('\'); if ($i -lt 0) { return $false }; $path = $path.Substring(0, $i)
    }
    try {
        $hklm = [Microsoft.Win32.RegistryKey]::OpenBaseKey('LocalMachine', 'Default')
        $k = $hklm.OpenSubKey($path, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::TakeOwnership)
        $acl = $k.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
        $acl.SetOwner($admins); $k.SetAccessControl($acl); $k.Close()
        $k = $hklm.OpenSubKey($path, [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::ChangePermissions)
        $acl = $k.GetAccessControl()
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule($admins, 'FullControl', 'ContainerInherit', 'None', 'Allow')
        $acl.SetAccessRule($rule); $k.SetAccessControl($acl); $k.Close()
        return $true
    } catch { return $false }
}

function Invoke-OfflineRegWrite {
    <#
        .SYNOPSIS 오프라인 레지스트리 쓰기/삭제를 시도하고, 권한 오류면 권한을 얻은 뒤 한 번 더 시도.
        .PARAMETER RegPath Registry::HKEY_LOCAL_MACHINE\LW_... 경로
        .PARAMETER Action  실제 작업 (scriptblock). 호출한 쪽의 변수를 그대로 읽는다(클로저 아님 → 스크립트 함수 사용 가능)
        .OUTPUTS 성공 $true / 실패 $false (예외를 던지지 않음)
    #>
    param([Parameter(Mandatory)][string]$RegPath, [Parameter(Mandatory)][scriptblock]$Action)
    try { & $Action; return $true } catch [System.UnauthorizedAccessException], [System.Security.SecurityException] { }
    catch {
        if ($_.Exception.Message -notmatch '(denied|거부|unauthorized|권한)') { return $false }
    }
    $sub = $RegPath -replace '^Registry::HKEY_LOCAL_MACHINE\\', ''
    if (-not (Grant-OfflineKeyAccess -SubKey $sub)) { return $false }
    try { & $Action; return $true } catch { return $false }
}
