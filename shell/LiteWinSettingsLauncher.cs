// LiteWinSettings.exe — 「LiteWin 설정」을 콘솔 창 없이 바로 여는 작은 실행 파일
//  * 관리자 권한 요청이 실행 파일 매니페스트에 들어 있어 UAC 확인 한 번으로 바로 열린다
//    (바로가기 → PowerShell → 관리자 PowerShell 로 창이 두 번 깜빡이던 문제 해결)
//  * PowerShell 을 이 프로세스 안에서 직접 돌린다(별도 콘솔 없음)
//  * 사용:  LiteWinSettings.exe [-FirstRun] [-ApplyPending]
// 빌드: build\Compile-LiteWinTools.ps1 (C# 5, .NET Framework 4.x)
using System;
using System.IO;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Text;
using System.Threading;
using System.Windows.Forms;

static class LiteWinSettingsLauncher
{
    [STAThread]
    static int Main(string[] args)
    {
        Application.EnableVisualStyles();

        // 1) 실행 파일 옆(..\app) — 저장소에서 직접 실행할 때 / 2) C:\ProgramData\LiteWin\app
        string script = Path.GetFullPath(Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..\\app\\LiteWinSettings.ps1"));
        if (!File.Exists(script))
            script = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "LiteWin\\app\\LiteWinSettings.ps1");
        if (!File.Exists(script))
        {
            MessageBox.Show("LiteWin 설정 스크립트를 찾을 수 없습니다:\n" + script, "LiteWin 설정", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 1;
        }

        bool firstRun = false, applyPending = false;
        foreach (string a in args)
        {
            string n = a.TrimStart('-', '/');
            if (n.Equals("FirstRun", StringComparison.OrdinalIgnoreCase)) firstRun = true;
            if (n.Equals("ApplyPending", StringComparison.OrdinalIgnoreCase)) applyPending = true;
        }

        InitialSessionState iss = InitialSessionState.CreateDefault();
        iss.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.Bypass;

        try
        {
            using (Runspace rs = RunspaceFactory.CreateRunspace(iss))
            {
                rs.ApartmentState = ApartmentState.STA;          // WinForms 는 STA 필요
                rs.ThreadOptions = PSThreadOptions.UseCurrentThread;
                rs.Open();
                using (PowerShell ps = PowerShell.Create())
                {
                    ps.Runspace = rs;
                    ps.AddCommand(script);
                    if (firstRun) ps.AddParameter("FirstRun");
                    if (applyPending) ps.AddParameter("ApplyPending");
                    ps.Invoke();
                    if (ps.HadErrors && ps.Streams.Error.Count > 0)
                    {
                        StringBuilder sb = new StringBuilder();
                        int n = 0;
                        foreach (ErrorRecord e in ps.Streams.Error)
                        {
                            sb.AppendLine(e.ToString());
                            if (++n >= 5) break;
                        }
                        Log(sb.ToString());
                    }
                }
            }
        }
        catch (Exception ex)
        {
            Log(ex.ToString());
            MessageBox.Show("LiteWin 설정을 여는 중 오류가 발생했습니다.\n\n" + ex.Message, "LiteWin 설정", MessageBoxButtons.OK, MessageBoxIcon.Error);
            return 2;
        }
        return 0;
    }

    static void Log(string text)
    {
        try
        {
            string dir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "LiteWin\\logs");
            Directory.CreateDirectory(dir);
            File.AppendAllText(Path.Combine(dir, "LiteWinSettings.log"), DateTime.Now.ToString("s") + " " + text + Environment.NewLine, Encoding.UTF8);
        }
        catch { }
    }
}
