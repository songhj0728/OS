// LiteWinCaption.exe — 모든 창에 맥식 창 버튼(닫기·최소화·전체화면)을 덧붙이는 작은 상주 프로그램
//
//  * 앱이 스스로 그리는 제목줄(Chrome, Discord, Steam, 설정 앱 등)에도 붙는다: 창 위에 떠 있는 별도 버튼이라서.
//  * 원래 오른쪽 버튼은 그대로 둔다(덧붙이기만 함).
//  * 활성 창 왼쪽 위에 붙는다. 전체화면 상태에서는 숨었다가 마우스를 화면 맨 위로 올리면 나타난다(맥과 같음).
//  * 설정: %LOCALAPPDATA%\LiteWin\Caption.ini  (LiteWin 설정 앱이 만든다)
//      [Caption]
//      Mode=traffic        ; traffic = 3개(닫기/최소화/전체화면), fullscreen = 전체화면 버튼만
//      OffsetX=10          ; 창 왼쪽 위에서의 위치 (96 DPI 기준 픽셀)
//      OffsetY=9
//      Exclude=game.exe,another.exe
//      F11Apps=chrome.exe,firefox.exe        ; 이 앱들은 전체화면을 F11 로
//      [Offsets]
//      chrome.exe=10,9
//
// 빌드: Build-LiteWin.ps1 이 Add-Type 으로 컴파일 (.NET Framework 4.x, C# 5 문법만 사용)
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.Windows.Forms;

namespace LiteWin
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            bool created;
            Mutex mutex = new Mutex(true, "Local\\LiteWinCaption", out created);
            if (!created) return;
            try { Native.SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch { }   // Per-Monitor v2
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Tracker t = new Tracker(CaptionConfig.Load());
            Application.Run(new ApplicationContext());
            GC.KeepAlive(t);
            GC.KeepAlive(mutex);
        }
    }

    // ------------------------------------------------------------------ 설정
    class CaptionConfig
    {
        public bool Traffic = true;
        public int OffsetX = 10, OffsetY = 9;
        public HashSet<string> Exclude = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        public HashSet<string> F11Apps = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        public Dictionary<string, Point> Offsets = new Dictionary<string, Point>(StringComparer.OrdinalIgnoreCase);

        public static CaptionConfig Load()
        {
            CaptionConfig c = new CaptionConfig();
            // 탐색기 창(explorer.exe)에는 붙이고, 셸/런처/원격 데스크톱 등은 제외
            foreach (string s in new[] { "LiteWinCaption.exe", "RetroBar.exe", "StartMenu.exe",
                                         "ShellExperienceHost.exe", "StartMenuExperienceHost.exe", "SearchHost.exe",
                                         "LockApp.exe", "mstsc.exe", "Flow.Launcher.exe" })
                c.Exclude.Add(s);
            foreach (string s in new[] { "chrome.exe", "msedge.exe", "firefox.exe", "brave.exe", "opera.exe", "vivaldi.exe", "whale.exe" })
                c.F11Apps.Add(s);

            string path = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "LiteWin\\Caption.ini");
            if (!File.Exists(path)) return c;
            string section = "";
            foreach (string raw in File.ReadAllLines(path))
            {
                string line = raw.Trim();
                if (line.Length == 0 || line.StartsWith(";") || line.StartsWith("#")) continue;
                if (line.StartsWith("[")) { section = line.Trim('[', ']').ToLowerInvariant(); continue; }
                int eq = line.IndexOf('=');
                if (eq <= 0) continue;
                string k = line.Substring(0, eq).Trim(), v = line.Substring(eq + 1).Trim();
                if (section == "caption")
                {
                    if (k.Equals("Mode", StringComparison.OrdinalIgnoreCase)) c.Traffic = !v.Equals("fullscreen", StringComparison.OrdinalIgnoreCase);
                    else if (k.Equals("OffsetX", StringComparison.OrdinalIgnoreCase)) int.TryParse(v, out c.OffsetX);
                    else if (k.Equals("OffsetY", StringComparison.OrdinalIgnoreCase)) int.TryParse(v, out c.OffsetY);
                    else if (k.Equals("Exclude", StringComparison.OrdinalIgnoreCase)) AddList(c.Exclude, v);
                    else if (k.Equals("F11Apps", StringComparison.OrdinalIgnoreCase)) AddList(c.F11Apps, v);
                }
                else if (section == "offsets")
                {
                    string[] xy = v.Split(',');
                    int x, y;
                    if (xy.Length == 2 && int.TryParse(xy[0].Trim(), out x) && int.TryParse(xy[1].Trim(), out y))
                        c.Offsets[k] = new Point(x, y);
                }
            }
            return c;
        }

        static void AddList(HashSet<string> set, string v)
        {
            foreach (string p in v.Split(','))
                if (p.Trim().Length > 0) set.Add(p.Trim());
        }
    }

    // ------------------------------------------------------------------ 버튼 창
    class Overlay : Form
    {
        public event Action<int> ButtonClicked;   // 0 닫기, 1 최소화, 2 전체화면
        readonly bool traffic;
        int hover = -1;
        float scale = 1f;
        const int D = 12, GAP = 8, PAD = 2;

        static readonly Color[] Fill = { Color.FromArgb(255, 95, 87), Color.FromArgb(254, 188, 46), Color.FromArgb(40, 200, 64) };
        static readonly Color KeyColor = Color.FromArgb(1, 2, 3);

        public Overlay(bool traffic)
        {
            this.traffic = traffic;
            FormBorderStyle = FormBorderStyle.None;
            ShowInTaskbar = false;
            StartPosition = FormStartPosition.Manual;
            AutoScaleMode = AutoScaleMode.None;
            BackColor = KeyColor;
            TransparencyKey = KeyColor;
            DoubleBuffered = true;
            Size = new Size(1, 1);
        }

        protected override bool ShowWithoutActivation { get { return true; } }

        protected override CreateParams CreateParams
        {
            get
            {
                CreateParams cp = base.CreateParams;
                cp.ExStyle |= 0x08000000 /*WS_EX_NOACTIVATE*/ | 0x00000080 /*WS_EX_TOOLWINDOW*/;
                return cp;
            }
        }

        protected override void WndProc(ref Message m)
        {
            if (m.Msg == 0x0021 /*WM_MOUSEACTIVATE*/) { m.Result = new IntPtr(3 /*MA_NOACTIVATE*/); return; }
            base.WndProc(ref m);
        }

        int Count { get { return traffic ? 3 : 1; } }

        public Size Measure(float s)
        {
            int d = (int)Math.Round(D * s), gap = (int)Math.Round(GAP * s), pad = (int)Math.Round(PAD * s);
            return new Size(pad * 2 + Count * d + (Count - 1) * gap, pad * 2 + d);
        }

        public void SetScale(float s)
        {
            if (Math.Abs(s - scale) > 0.01f) { scale = s; Invalidate(); }
        }

        Rectangle ButtonRect(int i)
        {
            int d = (int)Math.Round(D * scale), gap = (int)Math.Round(GAP * scale), pad = (int)Math.Round(PAD * scale);
            return new Rectangle(pad + i * (d + gap), pad, d, d);
        }

        int Kind(int i) { return traffic ? i : 2; }

        int HitTest(Point p)
        {
            for (int i = 0; i < Count; i++)
            {
                Rectangle r = ButtonRect(i);
                r.Inflate(2, 2);
                if (r.Contains(p)) return i;
            }
            return -1;
        }

        protected override void OnMouseMove(MouseEventArgs e)
        {
            int h = HitTest(e.Location) >= 0 ? 1 : -1;   // 맥처럼 한 버튼에 올리면 모든 기호 표시
            if (h != hover) { hover = h; Invalidate(); }
            base.OnMouseMove(e);
        }

        protected override void OnMouseLeave(EventArgs e)
        {
            if (hover != -1) { hover = -1; Invalidate(); }
            base.OnMouseLeave(e);
        }

        protected override void OnMouseUp(MouseEventArgs e)
        {
            int i = HitTest(e.Location);
            if (e.Button == MouseButtons.Left && i >= 0 && ButtonClicked != null) ButtonClicked(Kind(i));
            base.OnMouseUp(e);
        }

        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.None;   // 투명 키 색과 섞이지 않게 계단 없이 단색으로
            for (int i = 0; i < Count; i++)
            {
                Rectangle r = ButtonRect(i);
                using (SolidBrush b = new SolidBrush(Fill[Kind(i)])) g.FillEllipse(b, r);
                if (hover < 0) continue;
                using (Pen p = new Pen(Color.FromArgb(90, 30, 20), Math.Max(1f, 1.3f * scale)))
                {
                    int cx = r.X + r.Width / 2, cy = r.Y + r.Height / 2, q = r.Width / 4;
                    switch (Kind(i))
                    {
                        case 0: g.DrawLine(p, cx - q, cy - q, cx + q, cy + q); g.DrawLine(p, cx - q, cy + q, cx + q, cy - q); break;
                        case 1: g.DrawLine(p, cx - q, cy, cx + q, cy); break;
                        case 2: g.DrawLine(p, cx - q, cy + q, cx + q, cy - q);
                                g.DrawLine(p, cx + q, cy - q, cx, cy - q); g.DrawLine(p, cx + q, cy - q, cx + q, cy); break;
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------ 활성 창 추적
    class Tracker
    {
        readonly CaptionConfig cfg;
        readonly Overlay overlay;
        readonly Native.WinEventDelegate proc;
        readonly List<IntPtr> hooks = new List<IntPtr>();
        readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        readonly Dictionary<IntPtr, SavedWindow> fullscreen = new Dictionary<IntPtr, SavedWindow>();
        readonly Dictionary<int, string> exeCache = new Dictionary<int, string>();
        readonly int ownPid = Process.GetCurrentProcess().Id;
        IntPtr target = IntPtr.Zero;

        struct SavedWindow { public long Style; public Native.RECT Rect; }

        public Tracker(CaptionConfig cfg)
        {
            this.cfg = cfg;
            overlay = new Overlay(cfg.Traffic);
            overlay.ButtonClicked += OnButton;
            overlay.CreateControl();
            if (overlay.Handle == IntPtr.Zero) throw new InvalidOperationException("overlay handle");

            proc = new Native.WinEventDelegate(OnWinEvent);
            uint[][] ranges = {
                new uint[] { 0x0003, 0x0003 },   // EVENT_SYSTEM_FOREGROUND
                new uint[] { 0x000A, 0x000B },   // MOVESIZESTART/END
                new uint[] { 0x0016, 0x0017 },   // MINIMIZESTART/END
                new uint[] { 0x8001, 0x8003 },   // OBJECT_DESTROY/SHOW/HIDE
                new uint[] { 0x800B, 0x800B },   // OBJECT_LOCATIONCHANGE
            };
            foreach (uint[] r in ranges)
                hooks.Add(Native.SetWinEventHook(r[0], r[1], IntPtr.Zero, proc, 0, 0, 0x0000 | 0x0002 /*OUTOFCONTEXT|SKIPOWNPROCESS*/));

            timer.Interval = 200;
            timer.Tick += delegate { Update(); };
            timer.Start();
            Update();
        }

        void OnWinEvent(IntPtr hook, uint ev, IntPtr hwnd, int idObject, int idChild, uint thread, uint time)
        {
            if (idObject != 0 /*OBJID_WINDOW*/) return;
            if (ev == 0x800B && hwnd != target) return;   // 다른 창 이동은 무시
            if (ev == 0x8001) fullscreen.Remove(hwnd);
            Update();
        }

        string ExeOf(IntPtr hwnd)
        {
            uint pid;
            Native.GetWindowThreadProcessId(hwnd, out pid);
            if ((int)pid == ownPid) return "LiteWinCaption.exe";
            string name;
            if (exeCache.TryGetValue((int)pid, out name)) return name;
            try { name = Process.GetProcessById((int)pid).ProcessName + ".exe"; } catch { name = ""; }
            if (exeCache.Count > 500) exeCache.Clear();
            exeCache[(int)pid] = name;
            return name;
        }

        static string ClassOf(IntPtr hwnd)
        {
            StringBuilder sb = new StringBuilder(256);
            Native.GetClassName(hwnd, sb, sb.Capacity);
            return sb.ToString();
        }

        bool Eligible(IntPtr hwnd)
        {
            if (hwnd == IntPtr.Zero || hwnd == overlay.Handle) return false;
            if (!Native.IsWindowVisible(hwnd) || Native.IsIconic(hwnd)) return false;
            if (Native.GetAncestor(hwnd, 2 /*GA_ROOT*/) != hwnd) return false;
            int cloaked;
            if (Native.DwmGetWindowAttribute(hwnd, 14 /*DWMWA_CLOAKED*/, out cloaked, 4) == 0 && cloaked != 0) return false;
            long style = Native.GetWindowLongPtr(hwnd, -16).ToInt64();
            long ex = Native.GetWindowLongPtr(hwnd, -20).ToInt64();
            if ((ex & 0x80) != 0 || (ex & 0x08000000) != 0) return false;            // TOOLWINDOW / NOACTIVATE
            bool wasFull = fullscreen.ContainsKey(hwnd);
            if (!wasFull && (style & 0x00010000) == 0) return false;                  // WS_MAXIMIZEBOX 없는 창(대화상자 등) 제외
            string cls = ClassOf(hwnd);
            if (cls == "Shell_TrayWnd" || cls == "Shell_SecondaryTrayWnd" || cls == "Progman" || cls == "WorkerW" ||
                cls == "Windows.UI.Core.CoreWindow" || cls == "XamlExplorerHostIslandWindow") return false;
            return !cfg.Exclude.Contains(ExeOf(hwnd));
        }

        static Native.RECT Frame(IntPtr hwnd)
        {
            Native.RECT r;
            if (Native.DwmGetWindowAttribute(hwnd, 9 /*DWMWA_EXTENDED_FRAME_BOUNDS*/, out r, Marshal.SizeOf(typeof(Native.RECT))) != 0)
                Native.GetWindowRect(hwnd, out r);
            return r;
        }

        static Native.RECT MonitorRect(IntPtr hwnd)
        {
            Native.MONITORINFO mi = new Native.MONITORINFO();
            mi.cbSize = Marshal.SizeOf(typeof(Native.MONITORINFO));
            Native.GetMonitorInfo(Native.MonitorFromWindow(hwnd, 2), ref mi);
            return mi.rcMonitor;
        }

        static bool CoversMonitor(Native.RECT w, Native.RECT m)
        {
            return w.Left <= m.Left && w.Top <= m.Top && w.Right >= m.Right && w.Bottom >= m.Bottom;
        }

        void Hide()
        {
            if (overlay.Visible) overlay.Hide();
        }

        void Update()
        {
            IntPtr fg = Native.GetForegroundWindow();
            if (fg == overlay.Handle) return;
            if (!Eligible(fg)) { target = IntPtr.Zero; Hide(); return; }
            target = fg;

            Native.RECT r = Frame(fg);
            Native.RECT mon = MonitorRect(fg);
            if (CoversMonitor(r, mon))
            {
                // 전체화면: 마우스를 화면 맨 위에 올렸을 때만 표시 (LiteWin 이 만든 전체화면 / 브라우저 F11)
                bool ours = fullscreen.ContainsKey(fg) || cfg.F11Apps.Contains(ExeOf(fg));
                Point cur;
                Native.GetCursorPos(out cur);
                bool atTop = cur.Y <= mon.Top + 2 || (overlay.Visible && cur.Y <= mon.Top + overlay.Height + 30);
                if (!ours || !atTop) { Hide(); return; }
            }

            float s = Native.GetDpiForWindow(fg) / 96f;
            if (s <= 0) s = 1f;
            Point off = new Point(cfg.OffsetX, cfg.OffsetY);
            Point custom;
            if (cfg.Offsets.TryGetValue(ExeOf(fg), out custom)) off = custom;
            overlay.SetScale(s);
            Size sz = overlay.Measure(s);
            int x = r.Left + (int)Math.Round(off.X * s), y = r.Top + (int)Math.Round(off.Y * s);
            Native.SetWindowPos(overlay.Handle, IntPtr.Zero /*HWND_TOP*/, x, y, sz.Width, sz.Height,
                0x0010 /*NOACTIVATE*/ | 0x0040 /*SHOWWINDOW*/);
            if (!overlay.Visible) overlay.Visible = true;
        }

        void OnButton(int kind)
        {
            IntPtr hwnd = target;
            if (hwnd == IntPtr.Zero) return;
            switch (kind)
            {
                case 0: Native.PostMessage(hwnd, 0x0112, new IntPtr(0xF060), IntPtr.Zero); break;   // SC_CLOSE
                case 1: Native.PostMessage(hwnd, 0x0112, new IntPtr(0xF020), IntPtr.Zero); break;   // SC_MINIMIZE
                case 2: ToggleFullscreen(hwnd); break;
            }
            Update();
        }

        void ToggleFullscreen(IntPtr hwnd)
        {
            string exe = ExeOf(hwnd);
            if (cfg.F11Apps.Contains(exe)) { Native.SetForegroundWindow(hwnd); SendVk(new byte[] { 0x7A }); return; }   // F11
            if (ClassOf(hwnd) == "ApplicationFrameWindow")                                                           // Store 앱: Win+Shift+Enter
            { Native.SetForegroundWindow(hwnd); SendVk(new byte[] { 0x5B, 0x10, 0x0D }); return; }

            SavedWindow saved;
            if (fullscreen.TryGetValue(hwnd, out saved))
            {
                Native.SetWindowLongPtr(hwnd, -16, new IntPtr(saved.Style));
                Native.SetWindowPos(hwnd, IntPtr.Zero, saved.Rect.Left, saved.Rect.Top,
                    saved.Rect.Right - saved.Rect.Left, saved.Rect.Bottom - saved.Rect.Top, 0x0020 /*FRAMECHANGED*/ | 0x0004 /*NOZORDER*/);
                fullscreen.Remove(hwnd);
                return;
            }
            long style = Native.GetWindowLongPtr(hwnd, -16).ToInt64();
            if ((style & 0x01000000) != 0)   // 최대화 상태면 먼저 복원
            {
                Native.ShowWindow(hwnd, 9 /*SW_RESTORE*/);
                style = Native.GetWindowLongPtr(hwnd, -16).ToInt64();
            }
            SavedWindow sw = new SavedWindow();
            sw.Style = style;
            Native.GetWindowRect(hwnd, out sw.Rect);
            Native.RECT m = MonitorRect(hwnd);
            Native.SetWindowLongPtr(hwnd, -16, new IntPtr(style & ~(0x00C00000L | 0x00040000L)));   // CAPTION | THICKFRAME 제거
            Native.SetWindowPos(hwnd, IntPtr.Zero, m.Left, m.Top, m.Right - m.Left, m.Bottom - m.Top, 0x0020 | 0x0004);
            fullscreen[hwnd] = sw;
        }

        static void SendVk(byte[] vks)
        {
            foreach (byte vk in vks) Native.keybd_event(vk, 0, 0, UIntPtr.Zero);
            for (int i = vks.Length - 1; i >= 0; i--) Native.keybd_event(vks[i], 0, 2 /*KEYUP*/, UIntPtr.Zero);
        }
    }

    // ------------------------------------------------------------------ Win32
    static class Native
    {
        public delegate void WinEventDelegate(IntPtr hWinEventHook, uint eventType, IntPtr hwnd, int idObject, int idChild, uint dwEventThread, uint dwmsEventTime);

        [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
        [StructLayout(LayoutKind.Sequential)] public struct MONITORINFO { public int cbSize; public RECT rcMonitor; public RECT rcWork; public uint dwFlags; }

        [DllImport("user32.dll")] public static extern IntPtr SetWinEventHook(uint eventMin, uint eventMax, IntPtr hmod, WinEventDelegate proc, uint idProcess, uint idThread, uint flags);
        [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr hWnd, uint flags);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr hWnd, StringBuilder sb, int max);
        [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
        [DllImport("user32.dll", EntryPoint = "GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr hWnd, int index);
        [DllImport("user32.dll", EntryPoint = "SetWindowLongPtrW")] public static extern IntPtr SetWindowLongPtr(IntPtr hWnd, int index, IntPtr value);
        [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
        [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr hWnd, IntPtr after, int x, int y, int cx, int cy, uint flags);
        [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int cmd);
        [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
        [DllImport("user32.dll")] public static extern bool GetCursorPos(out Point p);
        [DllImport("user32.dll")] public static extern IntPtr MonitorFromWindow(IntPtr hWnd, uint flags);
        [DllImport("user32.dll")] public static extern bool GetMonitorInfo(IntPtr hMon, ref MONITORINFO mi);
        [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr hWnd);
        [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr ctx);
        [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
        [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out RECT value, int size);
        [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hWnd, int attr, out int value, int size);
    }
}
