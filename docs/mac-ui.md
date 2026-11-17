# 맥 입력 + UI 스타일

> **Dock·메뉴바 도구 (하나 선택)** — LiteWin 설정 > 모드 > 맥 입력 + UI 의 'Dock · 메뉴바 도구'
> - **Seelen UI** (기본, 무료·오픈소스 AGPL-3.0): 위쪽 메뉴바 + Dock. winget `Seelen.SeelenUI` 로 자동 설치.
> - **MyDockFinder** (유료, Steam 앱 1787090): 가장 맥과 비슷한 Dock·메뉴바·Launchpad. Steam 에서 직접 구매·설치. `steamapps\common\MyDockFinder\dock_64.exe` 를 찾아 켜고 끈다.
> - **Nexus Dock** (무료, 개인용): Dock 만. winget `WinStep.Nexus`. 쓰는 동안 Windows 작업표시줄은 자동 숨김.
>
> 어느 도구든 맥 UI 모드에서만 실행되고, 라이트/맥 입력 모드로 돌아가면 꺼진다(도구 자체의 자동 시작은 꺼 둠).


LiteWin 설정 > 모드 > **맥 입력 + UI 스타일** 에서 고르는 항목이다. 언제든 **라이트 윈도우**로 돌아가면 처음 값으로 복원된다.

| 항목 | 방식 | 추가 메모리 |
|---|---|---|
| 다크 모드 | Windows 설정값 | 0 |
| 작업표시줄 자동 숨기기 (Dock 처럼) | Windows 설정값 | 0 |
| 투명 효과 | Windows 설정값 | 0 |
| QuickLook — 스페이스바 미리보기 | 오픈소스 앱 (시작 프로그램 켜고 끔) | 약 30~60MB |
| Flow Launcher — Spotlight 대체 | 오픈소스 앱. ⌘Space 가 Flow 를 열도록 자동 연결 | 약 80~120MB |
| Windhawk — Dock 모양 작업표시줄 | 오픈소스 모드 플랫폼 (서비스 켜고 끔) | 약 20~40MB |

## Windhawk 로 Dock 모양 만들기 (수동 1회)
Windhawk 모드는 자동 설치 방법이 공개돼 있지 않아 한 번만 직접 고른다.
1. 시작 메뉴 > Windhawk 실행 → **Explore** 탭
2. **Windows 11 Taskbar Styler** 검색 → Install
3. 모드 설정(Settings)에서 테마 목록 중 Dock 계열 테마를 선택 → Save
4. LiteWin 이 '라이트 윈도우' 로 돌아가면 Windhawk 서비스가 꺼져서 원래 작업표시줄로 돌아온다.

## 창 버튼 (LiteWinCaption)
- 맥 UI 모드에서 **모든 활성 창** 왼쪽 위에 닫기·최소화·전체화면 버튼을 덧붙입니다. 원래 오른쪽 버튼은 그대로 남습니다.
- 전체화면 버튼 동작:
  - 브라우저: F11로 전체화면
  - Store 앱: Win+Shift+Enter
  - 그 밖의 앱: 테두리 없는 전체화면
  - 다시 누르면 원래 크기로 돌아옵니다.
- 전체화면에서는 마우스를 화면 맨 위로 올리면 버튼이 나타납니다.
- 앱의 탭이나 메뉴를 가리면 `%LOCALAPPDATA%\LiteWin\Caption.ini`를 고칩니다.
  - `[Offsets]`에 `앱.exe=x,y` 형식으로 위치를 조정합니다.
  - `Exclude=`에 넣은 앱에는 버튼을 붙이지 않습니다.
- 관리자 권한으로 실행된 창에는 Windows 보안 정책상 버튼이 동작하지 않을 수 있습니다.

## 넣지 않은 것
- 애플 SF 폰트, 아이콘, 배경화면, 커서: 저작권 때문에 포함하지 않는다.
- 원래 창 버튼 자체를 왼쪽으로 옮기기: 각 앱/DWM 이 그리는 것이라 안정적인 방법이 없다 → 대신 LiteWinCaption 이 덧붙인다.
- 상단 메뉴바: 창이 메뉴바를 덮는 문제가 있어 보류 (가볍고 제대로 된 방법이 생기면 추가).
