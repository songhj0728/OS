<#
    테마 적용 (배경화면 + 다크/라이트 모드) — Windows 정품 인증 여부와 관계없이 동작한다.
    인증 전에는 설정 > 개인 설정 화면이 잠기지만, 배경화면 지정(SystemParametersInfo)과
    다크/라이트 값은 잠기지 않으므로 LiteWin 설정의 '테마' 탭에서 그대로 바꿀 수 있다.
#>
. (Join-Path $PSScriptRoot 'LiteWin.Common.ps1')

if (-not ('LiteWin.Desktop' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace LiteWin {
    public static class Desktop {
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern bool SystemParametersInfo(int action, int param, string value, int winIni);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        static extern IntPtr SendMessageTimeout(IntPtr hWnd, int msg, IntPtr wParam, string lParam, int flags, int timeout, out IntPtr result);
        public static bool SetWallpaper(string path) { return SystemParametersInfo(20 /*SPI_SETDESKWALLPAPER*/, 0, path, 3 /*UPDATEINIFILE|SENDCHANGE*/); }
        public static void BroadcastThemeChange() {
            IntPtr r;
            // 앱/작업표시줄이 다크·라이트 변경을 바로 반영하게 알린다
            SendMessageTimeout(new IntPtr(0xffff), 0x001A /*WM_SETTINGCHANGE*/, IntPtr.Zero, "ImmersiveColorSet", 2 /*ABORTIFHUNG*/, 1000, out r);
            SendMessageTimeout(new IntPtr(0xffff), 0x001A, IntPtr.Zero, "WindowsThemeElement", 2, 1000, out r);
        }
    }
}
'@
}

function Get-LWThemes {
    <# LiteWin 테마 + Windows 기본(밝게/어둡게) — 이름, 배경, 모드 #>
    $dir = Join-Path $env:WINDIR 'Resources\Themes'
    $files = @(Get-ChildItem $dir -Filter 'LiteWin*.theme' -ErrorAction SilentlyContinue | Sort-Object Name) +
             @(Get-ChildItem $dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -in 'aero.theme', 'dark.theme' })
    foreach ($f in $files) {
        $text = [IO.File]::ReadAllText($f.FullName)   # .theme 은 UTF-16/ANSI 모두 있음 — BOM 으로 자동 판별
        $get = { param($k) if ($text -match "(?m)^\s*$k\s*=\s*(.+?)\s*$") { $Matches[1] } else { '' } }
        $name = & $get 'DisplayName'
        if ($name -like '@*') { $name = if ($f.Name -eq 'dark.theme') { 'Windows (어둡게)' } else { 'Windows (밝게)' } }
        $wp = [Environment]::ExpandEnvironmentVariables((& $get 'Wallpaper'))
        $mode = & $get 'AppMode'; if (-not $mode) { $mode = & $get 'SystemMode' }
        if (-not $mode) { $mode = if ($f.Name -eq 'dark.theme') { 'Dark' } else { 'Light' } }
        [pscustomobject]@{ Name = $name; File = $f.FullName; Wallpaper = $wp; Dark = ($mode -eq 'Dark') }
    }
}

function Set-LWTheme {
    <# 테마 적용: 다크/라이트 → 배경화면 → 변경 알림. 정품 인증과 무관 #>
    param([Parameter(Mandatory)]$Theme)
    $pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $v = [int](-not $Theme.Dark)
    Set-RegValue $pers 'AppsUseLightTheme' $v
    Set-RegValue $pers 'SystemUsesLightTheme' $v
    $desk = 'HKCU:\Control Panel\Desktop'
    Set-RegValue $desk 'WallpaperStyle' '10' String
    Set-RegValue $desk 'TileWallpaper' '0' String
    $ok = $true
    if ($Theme.Wallpaper -and (Test-Path $Theme.Wallpaper)) { $ok = [LiteWin.Desktop]::SetWallpaper($Theme.Wallpaper) }
    Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes' 'CurrentTheme' $Theme.File String
    [LiteWin.Desktop]::BroadcastThemeChange()
    Write-LWLog "테마 적용: $($Theme.Name)$(if (-not $ok) { ' (배경화면 지정 실패)' })"
    return $ok
}
