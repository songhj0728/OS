// LiteWinTheme.exe — 다크/라이트 모드에 맞춰 배경화면 짝을 바꿔 주는 작은 상주 프로그램
//   배경화면 파일 이름이 *_light / *_dark 로 끝나고 같은 폴더에 짝이 있으면, Windows 의 앱 모드(다크/라이트)가
//   바뀔 때 자동으로 맞는 쪽으로 바꾼다. 사용자가 다른 배경화면을 고르면 아무것도 하지 않는다.
//   레지스트리 변경 알림을 기다리기만 하므로 평소 CPU 사용은 0.
//   사용:  LiteWinTheme.exe            (상주)
//          LiteWinTheme.exe -once      (한 번 맞추고 종료)
//          LiteWinTheme.exe -set <경로> (배경화면 지정 후 종료)
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Threading;
using Microsoft.Win32;

static class LiteWinTheme
{
    [DllImport("advapi32.dll")]
    static extern int RegNotifyChangeKeyValue(IntPtr hKey, bool watchSubtree, int notifyFilter, IntPtr hEvent, bool asynchronous);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool SystemParametersInfo(int action, int param, string value, int winIni);

    const string Personalize = @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize";

    [STAThread]
    static int Main(string[] args)
    {
        if (args.Length >= 2 && args[0].Equals("-set", StringComparison.OrdinalIgnoreCase))
        {
            if (!File.Exists(args[1])) return 1;
            return SystemParametersInfo(20 /*SPI_SETDESKWALLPAPER*/, 0, args[1], 3) ? 0 : 2;
        }
        if (args.Length >= 1 && args[0].Equals("-once", StringComparison.OrdinalIgnoreCase)) { Apply(); return 0; }

        bool created;
        using (Mutex m = new Mutex(true, "Local\\LiteWinTheme", out created))
        {
            if (!created) return 0;
            Apply();
            using (RegistryKey k = Registry.CurrentUser.CreateSubKey(Personalize))
            {
                if (k == null) return 1;
                while (true)
                {
                    // 값이 바뀔 때까지 대기 (REG_NOTIFY_CHANGE_LAST_SET)
                    if (RegNotifyChangeKeyValue(k.Handle.DangerousGetHandle(), false, 4, IntPtr.Zero, false) != 0) return 2;
                    Thread.Sleep(400);
                    Apply();
                }
            }
        }
    }

    static void Apply()
    {
        try
        {
            int light = 1;
            using (RegistryKey k = Registry.CurrentUser.OpenSubKey(Personalize))
            {
                object v = k == null ? null : k.GetValue("AppsUseLightTheme");
                if (v is int) light = (int)v;
            }
            string cur;
            using (RegistryKey d = Registry.CurrentUser.OpenSubKey(@"Control Panel\Desktop"))
                cur = d == null ? null : d.GetValue("Wallpaper") as string;
            if (string.IsNullOrEmpty(cur)) return;

            string name = Path.GetFileNameWithoutExtension(cur);
            string want = light != 0 ? "_light" : "_dark";
            string other = light != 0 ? "_dark" : "_light";
            if (!name.EndsWith(other, StringComparison.OrdinalIgnoreCase)) return;   // 이미 맞거나 짝이 없는 배경
            string target = Path.Combine(Path.GetDirectoryName(cur), name.Substring(0, name.Length - other.Length) + want + Path.GetExtension(cur));
            if (File.Exists(target)) SystemParametersInfo(20, 0, target, 3);
        }
        catch { }
    }
}
