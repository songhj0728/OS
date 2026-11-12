; =============================================================================
;  MacKeys.ahk  —  윈도우에서 맥 키보드 단축키 쓰기 (AutoHotkey v2, 메모리 약 2~4MB)
;
;  PC 키보드 왼쪽 아래 배열을 맥 위치에 맞춰 해석한다.
;
;     PC  : [Ctrl] [Win]    [Alt]  [ Space ]
;     Mac : [Ctrl] [Option] [Cmd]  [ Space ]
;
;  즉  왼쪽 Alt = ⌘ Command,  왼쪽 Win = ⌥ Option.  오른쪽 Alt(한/영 키)는 건드리지 않는다.
;  맥 키보드(Magic Keyboard)를 연결한 경우에도 같은 위치라 그대로 쓰면 된다.
;
;  잠시 끄기/켜기 :  Ctrl + Alt + Win + F12   (트레이 아이콘이 바뀜)
;  설정 바꾸기   :  시작 메뉴 > LiteWin 설정 (또는 %LOCALAPPDATA%\LiteWin\MacKeys.ini 수정 후 Reload)
; =============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook true
InstallKeybdHook
SendMode "Input"
A_MenuMaskKey := "vkE8"   ; Alt/Win 단독 눌림으로 메뉴·시작메뉴가 튀어나오는 것 방지

; ------------------------------ 설정 ---------------------------------------
; LiteWin 설정 앱이 사용자별 MacKeys.ini 에 저장한다. 파일이 없으면 아래 기본값.
global IniFile := EnvGet("LOCALAPPDATA") "\LiteWin\MacKeys.ini"
ReadOpt(name, def) {
    try return IniRead(IniFile, "MacKeys", name, def)
    catch
        return def
}
global CapsLockToHangul := ReadOpt("CapsLockToHangul", "1") = "1"  ; Caps Lock 짧게 = 한/영, 길게(0.3초) = 대문자 고정
global OptionWordMove   := ReadOpt("OptionWordMove", "1") = "1"    ; ⌥←/→ 단어 이동, ⌥⌫ 단어 삭제 (창 스냅은 ⌃⌘방향키)
global CmdQuitApp       := ReadOpt("CmdQuitApp", "1") = "1"        ; ⌘Q = 앱 종료(Alt+F4)
global Spotlight        := ReadOpt("Spotlight", "windows")         ; windows = Windows 검색, flow = Flow Launcher(Alt+Space)
global GameAutoOff      := ReadOpt("GameAutoOff", "1") = "1"       ; 전체화면(테두리 없는) 게임 중에는 자동으로 매핑 끔

; 전체화면 앱(대부분의 게임)인지: 제목표시줄이 없고 화면 전체를 덮는 창
IsFullscreen() {
    if !GameAutoOff
        return false
    try {
        hwnd := WinExist("A")
        if !hwnd
            return false
        cls := WinGetClass(hwnd)
        if (cls = "Progman" || cls = "WorkerW" || cls = "Shell_TrayWnd")
            return false
        if (WinGetStyle(hwnd) & 0xC00000)   ; WS_CAPTION 이 있으면 일반 창
            return false
        WinGetPos(&x, &y, &w, &h, hwnd)
        return (x <= 0 && y <= 0 && w >= A_ScreenWidth && h >= A_ScreenHeight)
    } catch {
        return false
    }
}
Active() => !WinActive("ahk_group NoRemap") && !IsFullscreen()

; 이 프로그램이 앞에 있을 때는 매핑을 전부 끈다 (게임, 원격데스크톱, 가상머신 등)
GroupAdd "NoRemap", "ahk_exe mstsc.exe"
GroupAdd "NoRemap", "ahk_exe vmware.exe"
GroupAdd "NoRemap", "ahk_exe VirtualBoxVM.exe"
GroupAdd "NoRemap", "ahk_exe Parsec.exe"
; GroupAdd "NoRemap", "ahk_exe 게임이름.exe"   ; ← 게임은 이렇게 추가

; 터미널: ⌘C/⌘V 를 Ctrl+Shift+C/V 로 보내서 Ctrl+C(중단)와 겹치지 않게
GroupAdd "Terminal", "ahk_exe WindowsTerminal.exe"
GroupAdd "Terminal", "ahk_exe wt.exe"
GroupAdd "Terminal", "ahk_exe alacritty.exe"
GroupAdd "Terminal", "ahk_exe wezterm-gui.exe"
GroupAdd "Terminal", "ahk_exe mintty.exe"

; --------------------------- 켜기/끄기 -------------------------------------
#SuspendExempt
^!#F12:: {
    Suspend -1
    TrayTip "MacKeys", A_IsSuspended ? "맥 단축키 꺼짐" : "맥 단축키 켜짐", 1
}
#SuspendExempt false

; ======================= 여기부터 매핑 (NoRemap 제외) ======================
#HotIf Active()

; ---- ⌘ + 글자/숫자 → Ctrl + 같은 키 (⇧ 조합 포함) ----
; ⌘A 전체선택, ⌘S 저장, ⌘F 찾기, ⌘T 새 탭, ⌘N 새 창, ⌘P 인쇄, ⌘1~9 탭 이동 ...
; (Hotkey() 함수는 #HotIf 가 아니라 HotIf() 조건을 따르므로 여기서 따로 지정)
HotIf (*) => Active()
for key in StrSplit("a b d e f g i j k l n o p r s t u y = - / . ;", " ") {
    Hotkey "<!" key,  SendCtrl.Bind(key)
    Hotkey "<!+" key, SendCtrl.Bind("+" key)       ; ⌘⇧T(닫은 탭 다시 열기) 등
}
for key in StrSplit("0 1 2 3 4 5 6 7 8 9", " ")  ; 숫자는 ⇧ 조합 제외(⌘⇧3/4/5 = 스크린샷)
    Hotkey "<!" key, SendCtrl.Bind(key)
HotIf
SendCtrl(keys, *) => Send("^" keys)

; 복사/붙여넣기/잘라내기 — 터미널에서는 Ctrl+Shift
<!c:: Send(WinActive("ahk_group Terminal") ? "^+c" : "^c")
<!v:: Send(WinActive("ahk_group Terminal") ? "^+v" : "^v")
<!x:: Send "^x"
<!+v:: Send "^+v"                     ; 서식 없이 붙여넣기(앱이 지원할 때)

; 실행 취소 / 다시 실행
<!z::  Send "^z"
<!+z:: Send "^y"                      ; ⌘⇧Z = 다시 실행

; 창/앱
<!w:: Send "^w"                       ; 탭/창 닫기
<!q:: {
    if CmdQuitApp
        Send "!{F4}"
}
<!h:: WinMinimize "A"                 ; 숨기기(최소화)
<!m:: WinMinimize "A"                 ; 최소화
<!,:: Send "^,"                       ; 환경설정(지원하는 앱)
<^<!f:: Send "{F11}"                  ; ⌃⌘F 전체화면
<!sc029:: Send "!{Esc}"               ; ⌘` 다음 창(근사)
; ⌘Tab 은 왼쪽 Alt+Tab 그대로라 따로 매핑하지 않음

; Spotlight / 강제 종료 / 설정
<!Space:: Send(Spotlight = "flow" ? "!{Space}" : "#s")   ; ⌘Space = 검색 (Flow Launcher 선택 시 Alt+Space)
<!<#Esc:: Send "^+{Esc}"              ; ⌘⌥Esc = 작업 관리자
<!<^q:: DllCall("LockWorkStation")    ; ⌃⌘Q = 화면 잠금

; 스크린샷 (캡처 도구)
<!+3:: Send "#{PrintScreen}"          ; ⌘⇧3 전체 화면 → 사진\스크린샷 폴더에 저장
<!+4:: Send "#+s"                     ; ⌘⇧4 영역 캡처
<!+5:: Send "#+r"                     ; ⌘⇧5 화면 녹화(캡처 도구)

; ---- 텍스트 커서 이동 (⌘ = 줄/문서 끝, ⌥ = 단어) ----
<!Left::   Send "{Home}"
<!Right::  Send "{End}"
<!Up::     Send "^{Home}"
<!Down::   Send "^{End}"
<!+Left::  Send "+{Home}"
<!+Right:: Send "+{End}"
<!+Up::    Send "^+{Home}"
<!+Down::  Send "^+{End}"
<!BS::     Send "+{Home}{Delete}"     ; ⌘⌫ 줄 앞까지 삭제
<![:: Send "!{Left}"                  ; ⌘[ 뒤로
<!]:: Send "!{Right}"                 ; ⌘] 앞으로

; 창 스냅은 ⌃⌘방향키로 (⌥←/→ 를 단어 이동에 쓰기 때문)
<^<!Left::  Send "#{Left}"
<^<!Right:: Send "#{Right}"
<^<!Up::    Send "#{Up}"
<^<!Down::  Send "#{Down}"

#HotIf Active() && OptionWordMove
<#Left::   Send "^{Left}"
<#Right::  Send "^{Right}"
<#+Left::  Send "^+{Left}"
<#+Right:: Send "^+{Right}"
<#BS::     Send "^{BS}"
<#Delete:: Send "^{Delete}"

; ---- Caps Lock = 한/영 ----
#HotIf Active() && CapsLockToHangul
*CapsLock:: {
    if KeyWait("CapsLock", "T0.3") {          ; 0.3초 안에 뗌 → 한/영
        Send "{vk15}"
    } else {                                  ; 길게 누름 → Caps Lock 토글
        SetCapsLockState !GetKeyState("CapsLock", "T")
        KeyWait "CapsLock"
    }
}

#HotIf
