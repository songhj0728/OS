// LiteWinEdgeRedirect.exe
// Edge 를 지운 뒤에도 Windows 일부(설정 도움말, 시작메뉴/위젯 링크 등)는 "microsoft-edge:" 링크로 Edge 를 부른다.
// 이 작은 프로그램이 그 링크를 받아 Chrome(없으면 기본 브라우저)으로 연다. 상주하지 않는다.
// 빌드 시 Build-LiteWin.ps1 이 Add-Type 으로 컴파일한다(.NET Framework 4.x, 외부 의존성 없음).
using System;
using System.Diagnostics;
using System.IO;
using Microsoft.Win32;

public static class LiteWinEdgeRedirect
{
    [STAThread]
    public static int Main(string[] args)
    {
        string url = ExtractUrl(string.Join(" ", args));
        if (url == null) return 1;
        url = BingToGoogle(url);

        string chrome = FindChrome();
        try
        {
            ProcessStartInfo psi;
            if (chrome != null)
                psi = new ProcessStartInfo(chrome, "\"" + url.Replace("\"", "%22") + "\"");
            else
                psi = new ProcessStartInfo(url);   // 기본 브라우저
            psi.UseShellExecute = true;
            Process.Start(psi);
            return 0;
        }
        catch { return 2; }
    }

    // microsoft-edge:https://...   또는   microsoft-edge:?launchContext1=...&url=https%3A%2F%2F...
    static string ExtractUrl(string raw)
    {
        if (string.IsNullOrEmpty(raw)) return null;
        raw = raw.Trim().Trim('"');
        int i = raw.IndexOf("microsoft-edge:", StringComparison.OrdinalIgnoreCase);
        string rest = i >= 0 ? raw.Substring(i + "microsoft-edge:".Length) : raw;
        rest = rest.Trim().Trim('"');

        string candidate = null;
        int q = rest.IndexOf("url=", StringComparison.OrdinalIgnoreCase);
        if (rest.StartsWith("?") && q >= 0)
        {
            string v = rest.Substring(q + 4);
            int amp = v.IndexOf('&');
            if (amp >= 0) v = v.Substring(0, amp);
            candidate = Uri.UnescapeDataString(v);
        }
        else
        {
            candidate = rest;
        }

        // http/https 만 허용 (file:, javascript: 등 차단)
        Uri u;
        if (Uri.TryCreate(candidate, UriKind.Absolute, out u) &&
            (u.Scheme == Uri.UriSchemeHttp || u.Scheme == Uri.UriSchemeHttps))
            return u.AbsoluteUri;
        return null;
    }

    static string BingToGoogle(string url)
    {
        Uri u = new Uri(url);
        if (u.Host.EndsWith("bing.com", StringComparison.OrdinalIgnoreCase) &&
            u.AbsolutePath.StartsWith("/search", StringComparison.OrdinalIgnoreCase))
        {
            foreach (string part in u.Query.TrimStart('?').Split('&'))
            {
                if (part.StartsWith("q=", StringComparison.OrdinalIgnoreCase))
                    return "https://www.google.com/search?q=" + part.Substring(2);
            }
        }
        return url;
    }

    static string FindChrome()
    {
        string[] keys = {
            @"SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe",
            @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe"
        };
        foreach (RegistryKey hive in new[] { Registry.LocalMachine, Registry.CurrentUser })
        {
            foreach (string k in keys)
            {
                using (RegistryKey key = hive.OpenSubKey(k))
                {
                    if (key == null) continue;
                    string p = key.GetValue("") as string;
                    if (!string.IsNullOrEmpty(p) && File.Exists(p.Trim('"'))) return p.Trim('"');
                }
            }
        }
        return null;
    }
}
