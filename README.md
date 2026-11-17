# LiteWin: Windows 10처럼 가볍고 익숙한 Windows 11 Pro

**Microsoft 공식 ISO**를 내 PC에서 직접 가공해 가벼운 Pro 설치 USB/ISO를 만드는 스크립트입니다.
기본 목표는 **광고·번들 앱 없이 Windows 10 이하처럼 익숙한 화면**(클래식 작업표시줄·시작 메뉴·오른쪽 클릭 메뉴)입니다.
맥 키보드·맥 화면이 필요한 사람을 위해 **「LiteWin 설정」** 앱에서 **라이트 윈도우(기본) ↔ 맥 입력 ↔ 맥 입력+UI** 모드를 언제든 오갈 수 있습니다.

- **커널과 시스템은 진짜 Windows 11 그대로입니다.** 일반 프로그램, 드라이버, 게임, 안티치트, 은행·보안 프로그램이 똑같이 동작합니다.
- **32비트 프로그램은 WOW64로 그대로 실행됩니다.** 32비트 프로그램을 켤 때만 메모리를 씁니다.
- **ISO는 Microsoft에서 직접 받습니다.** LiteWin은 수정한 Windows를 배포하지 않습니다. 정품 인증은 **본인 Pro 라이선스**로 합니다.
- **시스템 파일을 강제로 지우지 않습니다.** tiny11과 달리 Windows Update와 sfc/DISM 복구가 정상 동작합니다.

## 무엇이 빠지고 무엇이 남나

| 빠짐 | 남음 / 대체 |
|---|---|
| **Edge 브라우저** — 설치 이미지 단계에서 제거 (파일 연결·연결 프로그램 목록에도 안 남음) | **WebView2 런타임 유지**: 앱 화면 표시용이라 게임 런처, Discord, 위젯 등이 필요로 함 |
| Edge 전용 링크(`microsoft-edge:`) | **Chrome으로 자동 연결** (작은 리다이렉트 프로그램, 상주 안 함) |
| — | **Google Chrome = 기본 브라우저** (설치 이미지에 포함, 작업표시줄 고정) |
| Office 계열 (Microsoft 365, OneNote, Outlook) | — |
| Copilot, Recall, 위젯, Teams 자동설치, 광고·추천, Bing 웹검색 | Windows Update, Defender, 방화벽 |
| 위젯, Clipchamp, 뉴스, 날씨, 솔리테어, 지도, 영화 및 TV 등 | **사진, 미디어 플레이어**, 캡처 도구, 계산기, 메모장, 그림판, 터미널 |
| Xbox 앱 일체 (게임 탭에서 다시 설치 가능) | Microsoft Store, winget, 한국어 IME, .NET, VC++ 런타임 |

Edge를 다시 쓰고 싶으면 LiteWin 설정 > 브라우저에서 Edge를 체크하면 다시 설치됩니다.

### 빌드 프로필
프로필마다 **ISO를 따로** 만듭니다. 프로필은 **이미지에서 무엇을 지울지**와 **첫 로그인 마법사에서 미리 골라 둘 항목**을 정합니다. 나머지는 설치 후 바꿀 수 있습니다.

| 프로필 | 특징 | 마법사 기본 선택 |
|---|---|---|
| **Standard** (기본) | 위 표 그대로. 일상·업무용 | 라이트 윈도우 (클래식) |
| **Minimal** | 카메라·위젯까지 제거, 검색 색인·최대 절전·SysMain 끔 | 라이트 윈도우 |
| **Gaming** | Standard와 같은 제거 범위 + 마법사에 **게임 단계** | 라이트 윈도우 + Steam, Epic, Discord, GPU 드라이버 |

맥 입력·맥 UI는 어느 프로필에서나 원할 때만 켜는 옵션입니다.

## 첫 로그인 마법사와 「LiteWin 설정」 앱
- **첫 로그인**에 Windows 설치 화면(OOBE)처럼 전체 화면 마법사가 한 단계씩 나옵니다: **암호 → 계정 종류 → (Administrator 암호) → 브라우저 → 모드 → 테마 → 사진·동영상 → 게임(Gaming만)**.
  - 단계마다 **[다음] [뒤로] [건너뛰기]**가 있고, **[모두 기본값으로 건너뛰기]**로 한 번에 끝낼 수도 있습니다.
- 이후에는 시작 메뉴의 **LiteWin 설정**에서 같은 항목을 탭으로 언제든 바꿉니다: 계정, 모드, 테마, 사진·동영상, 게임(Gaming만), 브라우저, 정보.
- 창은 열었을 때만 실행되고, 적용 중에는 콘솔 창 없이 진행 막대만 보입니다.

### 모드

| 모드 | 조작 | 화면(셸) |
|---|---|---|
| **라이트 윈도우 (기본)** | 일반 Windows | **클래식**: Windows 10 작업표시줄(ExplorerPatcher) 또는 Win95~7 작업표시줄(RetroBar) + Win7 시작 메뉴(Open-Shell) 또는 Win10 시작 메뉴 |
| 맥 입력 | ⌘/⌥, Caps Lock=한/영, **맥 F열**, 볼륨 12단계, 마우스 가속, 휠 방향, 트랙패드 | 클래식 (라이트와 같음) |
| 맥 입력 + UI | 맥 입력과 같음 | **Dock·메뉴바 도구**(아래 표에서 선택), **모든 창에 맥식 창 버튼(신호등)**, 다크 모드·투명 효과, QuickLook·Flow Launcher(선택) |

- 모드를 바꾸면 그 자리에서 대부분 적용되고, **재부팅(또는 로그아웃)하면 완전히 반영**됩니다.
- 로그인할 때마다 LiteWin 셸이 현재 모드를 다시 적용합니다.
- 라이트 윈도우로 돌아가면 **맥 스타일을 처음 켜기 전의 값**으로 복원됩니다.
- 작업표시줄 단추에 프로그램 이름 표시(라벨)는 선택 사항입니다.
- 맥 입력은 **고를 때만** 키보드 프로그램(AutoHotkey 기반, 화면에 안 보임)을 켭니다. 일부 게임 안티치트가 키 변환 프로그램을 싫어할 수 있어서, 켤 때 경고를 한 번 보여 줍니다.

**작업표시줄 / 시작 메뉴 (재설치 없이 설정 앱에서 전환)**

| 스타일 | 작업표시줄 | 시작 메뉴 |
|---|---|---|
| 클래식 (라이트 / 맥 입력) | **Windows 10 스타일 (ExplorerPatcher, 기본)** 또는 Windows 95~7 스타일 (RetroBar) | Windows 7 스타일 (Open-Shell) 또는 Windows 10 스타일 (ExplorerPatcher) |
| 맥 (맥 입력 + UI) | 아래 Dock·메뉴바 도구 중 하나 | 도구 자체 메뉴 / Windows 기본 |

**구성요소 관리자 (Windows Update와 함께 동작)**
- ExplorerPatcher(GPL-2.0, 공식 GitHub 릴리스)를 비롯한 셸 구성요소는 **설정 > 앱 목록에 보이지 않고** 자동으로 관리됩니다.
- **업데이트 시점**
  - 부팅할 때, Windows Update 설치 직후, 하루 한 번 확인합니다.
  - 새 버전은 **배포 후 7일이 지난 것만**, 해시를 확인한 뒤 설치합니다.
  - 사용 중이라면 다음 부팅 때 적용합니다.
  - 7일 기준과 자동 업데이트 켜기/끄기는 설정 앱의 「정보」 탭에서 바꿀 수 있습니다.
- **기능 업데이트 보호**
  - 기능 업데이트(예: 24H2→25H2)가 받아졌거나 업그레이드 차단 표시가 보이면, ExplorerPatcher를 **잠시 제거**합니다. 그동안 클래식 작업표시줄은 RetroBar가 대신합니다.
  - 업그레이드가 끝나면 최신판으로 다시 설치합니다.
  - 과거에 Microsoft가 ExplorerPatcher 설치 PC의 업그레이드를 막은 적이 있어서 넣은 기능입니다.
- **자동 대체:** 업데이트 뒤 탐색기가 10분 안에 3번 이상 비정상 종료되면 RetroBar로 자동 전환합니다.
- Windows 시스템 파일은 바꾸지 않으므로 매월 보안 업데이트에는 영향이 없습니다.
- ExplorerPatcher는 Windows 보안(Defender)이 오탐지해 설치를 막은 적이 있어서, **관리자만 쓸 수 있는 두 위치(`C:\Program Files\ExplorerPatcher`, `C:\Windows\dxgi.dll`)만 검사 예외**로 둡니다. 사용자 폴더는 제외하지 않습니다. 예외를 없애려면 설정 > Windows 보안 > 바이러스 및 위협 방지 > 제외에서 지우세요.

**LiteWin 셸 계층**
- Windows의 작업표시줄과 시작 메뉴는 **지우지 않고 숨기기만** 합니다. 그래서 업데이트가 안전하고, Microsoft가 구버전 기능을 없애도 영향을 받지 않습니다.
- ExplorerPatcher는 공식 배포판을 수정 없이 쓰고, LiteWin은 설정값만 바꿉니다. 예비로 쓰는 RetroBar는 공개 셸 API만 사용해 Windows 변경의 영향을 가장 적게 받습니다.
- **창 버튼 (LiteWinCaption)**
  - 활성 창 왼쪽 위에 닫기·최소화·전체화면 버튼을 덧붙입니다. Chrome처럼 제목줄을 스스로 그리는 앱에도 붙습니다.
  - 전체화면에서는 숨었다가 마우스를 화면 맨 위로 올리면 나타납니다.
  - 버튼 3개 또는 전체화면 버튼만 고를 수 있습니다.
  - 앱별 위치 조정과 제외 목록은 `%LOCALAPPDATA%\LiteWin\Caption.ini`에서 설정합니다.
- **Dock·메뉴바 도구** (설정 > 모드 > 맥 입력 + UI 에서 하나 선택, 맥 UI 모드에서만 실행되고 다른 모드로 돌아가면 꺼짐)

  | 도구 | 맥과 닮은 정도 | 비용 | 설치 |
  |---|---|---|---|
  | **Seelen UI** (기본) | 위쪽 메뉴바 + Dock | 무료, 오픈소스(AGPL-3.0) | LiteWin이 winget으로 자동 설치 |
  | **MyDockFinder** | 가장 가까움: 맥식 Dock(확대·애니메이션), 위쪽 메뉴바, Launchpad | 유료(약 5달러), 소스 비공개 | **Steam에서 직접 구매·설치**. 고르면 Steam 페이지를 엽니다. 설치 후 [적용]을 다시 누르면 맥 UI와 함께 켜짐 |
  | **Nexus Dock** | Dock만 (확대 효과). 쓰는 동안 Windows 작업표시줄 자동 숨김 | 무료(개인용) | LiteWin이 winget으로 자동 설치 |
  | 사용 안 함 | Windows 작업표시줄 가운데 정렬 | — | — |

  - 도구 자체의 "Windows 시작 시 실행"은 꺼 두고, LiteWin 셸이 맥 UI 모드일 때만 띄웁니다.
  - 화면 위 메뉴바에 지금 앱의 "파일·편집·보기" 메뉴가 나오는 macOS 방식은 Windows 구조상 어떤 도구도 완전히 재현하지 못합니다.
- 맥 UI 상세 설명은 [docs/mac-ui.md](docs/mac-ui.md)에 있습니다.

### 사진·동영상
- **동영상(HEVC/H.265 포함)은 MPC-BE**, **아이폰 사진(.heic/.heif)은 ImageGlass**가 설치 이미지에 들어 있고 기본 앱으로 지정됩니다. 더블클릭하면 바로 열리고, 유료 코덱이 필요 없습니다.
- 그 밖의 사진은 Windows 사진 앱으로 열립니다.
- 탐색기 미리보기나 사진 앱에서도 더 많은 형식을 보려면 아래에서 고르세요.

| 옵션 | 내용 |
|---|---|
| **무료 코덱 확장 팩** | VP9, AV1, HEIF(아이폰 .heic), 카메라 RAW, WebP, MPEG-2. 기본 앱과 탐색기 미리보기에 함께 적용되고 상주 메모리는 0 |
| HEVC 확장 | 유료(약 1,000원)라 Store 페이지만 엽니다. MPC-BE를 쓰면 필요 없음 |
| **ImageGlass** | EXIF 정보 패널, 80여 개 이미지 형식 |
| **MPC-BE** | 코덱 설치 없이 VP9, AV1, HEVC, 10bit, HDR, MKV 재생 |

### 게임 (Gaming 프로필, 모두 옵션)
- Standard·Minimal에는 게임 단계가 없습니다. Xbox도 기본으로 설치하지 않고 여기서 고를 때만 설치합니다.
- **플랫폼**: Xbox(앱, 게임 바, 로그인), Steam, Epic Games, Battle.net, EA app, Ubisoft Connect, GOG Galaxy, 리그 오브 레전드, 발로란트, Rockstar, Minecraft, Playnite
- **커뮤니티·브라우저**: Discord, **Discord Phoenix(Rust 네이티브)**, Opera GX
  - Phoenix는 현재 공개 베타 배포 경로가 없어 회색으로 표시됩니다. 배포가 시작되면 `apps/catalog.json`에 패키지 ID만 넣으면 활성화됩니다.
- **드라이버**: GPU 제조사(NVIDIA, AMD, Intel)를 자동 감지해 공식 드라이버 페이지를 엽니다.
- 발로란트(Vanguard)는 TPM 2.0과 보안 부팅이 필요합니다. 조건이 맞지 않는 PC에서는 경고를 표시합니다.
- 맥 입력을 켰다면, 맥 단축키는 **전체화면 게임 중 자동으로 꺼지게** 할 수 있습니다(설정 > 모드).

## 맥 입력 단축키 (맥 입력 모드를 고른 경우만)
왼쪽 Alt는 ⌘, 왼쪽 Win은 ⌥로 동작합니다. 맥 키보드를 연결해도 키 위치가 같아서 그대로 쓰면 됩니다.

| 맥 | 동작 |
|---|---|
| ⌘C / V / X / Z / ⇧Z, ⌘A·S·F·T·⇧T·W·N·P·1~9 | Ctrl 조합과 같은 기능 (터미널에서는 Ctrl+Shift+C/V) |
| ⌘Q / ⌘H / ⌘M / ⌘Tab | 앱 종료 / 숨기기 / 최소화 / 앱 전환 |
| ⌘Space | 검색 (Flow Launcher를 켰다면 Flow) |
| ⌘←/→/↑/↓, ⌥←/→, ⌥⌫, ⌘⌫ | 줄·문서 처음/끝, 단어 이동/삭제, 줄 앞까지 삭제 |
| ⌘⇧3 / 4 / 5 | 전체 스크린샷 / 영역 캡처 / 화면 녹화 |
| ⌃⌘F / ⌃⌘Q / ⌘⌥Esc / ⌃⌘방향키 | 전체화면 / 잠금 / 작업 관리자 / 창 스냅 |
| Caps Lock | 짧게 누르면 한/영, 길게 누르면 Caps Lock |
| F11 / F12 | 볼륨을 0~100% 사이 **12단계**로 조절 (맥과 같음) |
| Ctrl+Alt+Win+F12 | 단축키 잠시 끄기/켜기 |

- **전체화면 앱·게임에서도 똑같이 동작합니다.**
  - 일반 키(WASD, Ctrl, Space 등)는 건드리지 않고 그대로 통과합니다. ⌘ 조합과 F열만 바뀝니다.
  - 그래서 맥과 마찬가지로 게임에서 Ctrl은 진짜 Ctrl입니다.
  - 로그인 화면과 UAC 창에서는 동작하지 않습니다.

**F열 (맥 기본)**

| F1 / F2 | F3 | F4 | F5 | F6 | F7 / F8 / F9 | F10 / F11 / F12 |
|---|---|---|---|---|---|---|
| 밝기 ↓↑ (노트북 화면 + 외부 모니터 DDC/CI) | 작업 보기 (Mission Control) | 검색 (Spotlight) | 받아쓰기 | 방해 금지 (알림 끄기) | 이전 / 재생·정지 / 다음 | 음소거 / 볼륨 ↓↑ |

- **⌥(왼쪽 Win) + F키**는 맥의 Fn + F키처럼 일반 F1~F12로 동작합니다.
- 맥의 "F1, F2 등을 표준 기능 키로 사용" 옵션도 있습니다.
- Alt+F4, Ctrl+F5처럼 다른 키와 함께 누르면 그대로 통과합니다.

## 만드는 방법
준비물은 다음과 같습니다.
- Windows 10/11 PC와 관리자 권한 **Windows PowerShell**
- 인터넷 연결
- 여유 공간 약 25GB
- **oscdimg**: `winget install Microsoft.WindowsADK`를 실행한 뒤 "배포 도구"만 선택합니다. 이 단계 대신 `-NoIso`로 폴더까지만 만들고 Rufus로 USB를 만들어도 됩니다.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build\Build-LiteWin.ps1                          # ISO를 Microsoft에서 직접 받아 빌드 (Standard)
.\build\Build-LiteWin.ps1 -IsoPath D:\Win11.iso    # 이미 받은 공식 ISO 사용
.\build\Build-LiteWin.ps1 -ProfileName Gaming      # 프로필별로 따로 빌드
.\build\Build-LiteWin.ps1 -Release                 # 가장 작은 ISO (오래 걸림)
```

- **ISO 다운로드**는 `build\Get-WindowsIso.ps1`이 처리합니다.
  - Microsoft 공식 다운로드 API로 링크를 받고(오픈소스 Fido 사용), Microsoft 서버에서 직접 내려받습니다.
  - Microsoft가 자동 다운로드를 막으면 공식 페이지를 열어줍니다.
  - 다운로드가 끝나면 SHA-256을 표시하니, 공식 페이지에 있는 해시와 비교하세요.
- **Chrome 기업용 설치 파일**은 Google에서 받은 뒤 **디지털 서명을 확인**하고 이미지에 넣습니다.
- 결과물은 `out\LiteWin-<프로필>.iso`입니다. 자주 쓰는 옵션은 다음과 같습니다.
  - `-SplitForFat32`: install.wim이 4GB를 넘으면 FAT32 USB용으로 분할
  - `-BypassHardwareCheck`: TPM 검사 등을 우회. 발로란트를 못 쓰게 되고, MS가 업데이트를 보장하지 않음
  - `-NoChrome`: Chrome을 넣지 않음 (이 경우 Edge도 제거하지 않음)
  - `-SetupBackground '#2B2F38'`: Windows 설치 화면 배경색 (빈 값이면 바꾸지 않음)
- 빌드 기록은 `out\LiteWin-build.log`에 남고, 끝에 경고 요약이 표시됩니다.

### 계정
- Windows 설치 화면(OOBE)은 계정·Microsoft 로그인·이메일·지역을 **묻지 않습니다**. 계정 이름은 자동으로 `user`(관리자 그룹)입니다.
- 첫 로그인 마법사:
  1. **암호**: `user` 계정의 암호를 정합니다(선택). 비워 두면 암호 없이 로그인합니다.
  2. **계정 종류**: 오른쪽 아래 **"기본 제공 Administrator 계정으로 사용"** 체크박스. 체크하면 보안 경고를 두 번 확인합니다.
  3. Administrator를 골랐다면 **1번 암호를 그대로 쓸지, 새로 정할지** 묻습니다. 1번에서 암호를 비웠다면 이 질문 없이 바로 새 암호를 정합니다(Administrator는 암호 필수).
  4. 마법사를 마치면 적용됩니다. Administrator를 골랐다면 로그아웃 → Administrator 로그인 → 설정 적용 → `user` 계정 삭제(바탕 화면 등의 파일은 복사) 순서로 진행됩니다.
- 나중에 LiteWin 설정 > **계정**:
  - **[계정 설정…]** 창: 이 PC의 계정을 **프로필 그림 + 이름** 목록으로 보여 줍니다.
    - 왼쪽 아래 **[사용자 추가]**, 그 옆 **[수정]**(계정을 고르면 켜짐).
    - 수정: 암호가 있는 계정은 **현재 암호를 먼저 확인** → 프로필 옵션에서 이름·암호 변경(또는 암호 없애기) → **수정 완료 때 기존 암호를 한 번 더 확인**.
    - 오른쪽 아래 **[적용] [닫기]**. 바뀐 내용은 [적용]을 눌러야 실제로 바뀝니다. 적용하지 않고 닫으면 "저장하지 않은 변경사항이 있습니다. 닫으시겠습니까?"(확인 = 닫기 / 취소 = 계속하기)를 묻습니다.
    - 지금 로그인한 계정의 이름은 로그아웃 후 화면에 반영됩니다. 사용자 폴더(`C:\Users\…`) 이름은 Windows 특성상 바뀌지 않습니다.
  - **지금 계정의 종류**:
    - **관리자** (기본): 일반적인 Windows 관리자. 필요할 때 확인 창이 뜹니다.
    - **확인 창 없는 관리자**: 같은 계정·데이터 그대로, 사용자 계정 컨트롤(UAC) 확인 창만 끕니다. 경고 후 적용.
    - **기본 제공 Administrator로 전환**: 바탕 화면·문서·다운로드·사진·음악·동영상·즐겨찾기를 옮기고, 원하면 기존 계정을 남겨 둡니다. 보안 경고를 두 번 확인해야 하고 암호가 반드시 있어야 합니다. 프로그램 설정 같은 계정별 데이터는 Windows가 옮기는 기능을 지원하지 않아 그대로 옮겨지지 않습니다.
- **Microsoft 계정으로 로그인해도 로컬 계정이 Microsoft 계정으로 바뀌지 않게** 막아 둡니다. Store·Xbox 같은 앱 안에서의 로그인은 그대로 됩니다.

### 브라우저
- 기본은 Chrome입니다. LiteWin 설정 > **브라우저** 탭에서 Chrome, Edge, Brave, 네이버 웨일, Opera, Firefox를 설치·제거하고 기본 브라우저를 고를 수 있습니다. 첫 로그인 마법사에도 같은 탭이 있습니다.
- 마지막 남은 브라우저는 지우지 않습니다. Edge를 지워도 WebView2 런타임은 남깁니다.
- Windows 11은 프로그램이 현재 사용자의 기본 브라우저를 바꾸지 못하게 막아 두었습니다. 그래서 기본 브라우저를 바꾸면 Windows 기본 앱 화면이 열리고, 여기서 [기본값으로 설정]을 한 번 눌러야 합니다. 앞으로 만들 계정에는 자동으로 적용됩니다.

### 배경화면과 테마
- 설정 > 개인 설정 > **테마**에 LiteWin 테마 4개가 들어 있습니다. 테마마다 배경화면과 다크/라이트 모드가 짝지어져 있어서, 고르면 둘이 같이 바뀝니다.

  | 테마 | 배경화면 | 모드 |
  |---|---|---|
  | **LiteWin 라이트 (기본)** | wave_light | 라이트 |
  | LiteWin 다크 | wave_dark | 다크 |
  | LiteWin 리본 | ribbon | 다크 |
  | LiteWin 도형 | shapes | 라이트 |

- 새 계정은 LiteWin 라이트로 시작합니다. 강제 설정이 아니라 기본값일 뿐이라, 배경화면·잠금 화면·색은 Windows 설정에서 자유롭게 바꿀 수 있습니다.
- 그림 파일은 `C:\Windows\Web\Wallpaper\LiteWin`에 있습니다. 개인 설정 > 배경 > 사진 찾아보기에서 직접 골라도 됩니다.
- 그림을 바꾸거나 추가하려면 저장소의 `assets\wallpapers` 폴더를 고친 뒤 다시 빌드하세요.
- Windows 기본 배경 파일 자체를 LiteWin 배경으로 바꿔 두어서, 설치 직후 첫 화면부터 바로 wave_light가 보입니다.
- 정품 인증 전에는 Windows가 개인 설정을 잠그지만, LiteWin 설정 > **테마**에서는 인증 전에도 테마를 고를 수 있습니다.

### 정품 인증
- 본인 Windows 11 Pro 라이선스로 인증합니다. LiteWin은 인증 우회를 하지 않습니다.
- LiteWin 설정 > **정보 > 진단 및 복구 후 인증**: "정품 인증 서버에 연결할 수 없음"의 흔한 원인(시계 어긋남, 꺼진 서비스, 네트워크 차단)을 확인·복구한 뒤 다시 인증합니다.
- **제품 키 입력…**으로 키를 넣을 수 있습니다. 가상머신은 PC의 디지털 라이선스를 쓰지 못하므로 키가 필요합니다. 같은 기능을 `tools\Repair-Activation.ps1`로도 실행할 수 있습니다.

### 빌드 부담 줄이기 / 업데이트
- **ISO는 처음 한 번만:** 설정 앱·모드·셸·맥 키보드처럼 LiteWin 자체 기능이 바뀐 것은 ISO를 다시 만들 필요가 없습니다. 설치된 PC에서 **LiteWin 설정 > 정보 > LiteWin 업데이트 확인**을 누르면 이 저장소의 최신 [Release](../../releases)에서 받아 바꿉니다.
  - 받은 파일은 GitHub가 계산한 SHA-256과 같을 때만 설치합니다. 실패하면 기존 버전이 그대로 남습니다.
  - ISO를 다시 만들어야 하는 경우: 지우는 앱 목록, 레지스트리 정책, Edge 제거, 기본 배경, 설치 단계(`setup`)를 바꿨을 때뿐입니다.
- **Release 만들기:** `main`에 push하거나 Actions > **release** > Run workflow를 누르면 `LiteWin-update.zip`이 자동으로 Release에 올라갑니다. 토큰 설정은 필요 없습니다.
  - Release에는 이 저장소의 코드(설정 앱·스크립트)와 컴파일된 exe만 들어갑니다. Windows ISO나 수정한 이미지는 절대 올리지 않습니다.
  - 다른 저장소에 올리고 싶으면 variable `RELEASE_REPO`와 secret `LITEWIN_RELEASE_TOKEN`을 설정하고, 빌드할 때 `-UpdateRepo`로 그 저장소를 지정합니다.
- **기본 빌드 = 빠른 빌드:** `.\build\Build-LiteWin.ps1`만 실행해도 캐시를 씁니다(예전 `-Fast`와 같음).
  - 중간 결과를 `C:\LiteWinWork\cache`에 저장해 두고 다음 빌드부터 재사용합니다. 재사용 대상은 ISO 내용, Pro 이미지, 앱 제거·레지스트리·Edge 제거까지 끝난 이미지, 내려받은 설치 파일(7일간)입니다.
  - 지우는 앱 목록이나 레지스트리 정책을 바꾼 경우에만 그 단계를 다시 합니다.
  - 빌드 프로세스 우선순위를 '낮음'으로 두어 빌드 중에도 PC를 쓸 수 있습니다 (`-Priority Normal`로 되돌림).
  - 가장 작은 ISO가 필요할 때만 `-Release`(캐시 없음 + 구성요소 정리 + 최대 압축, 오래 걸림).
  - 캐시는 10GB 안팎을 차지합니다. `cache` 폴더를 지우면 처음부터 다시 만듭니다.
- **개발 중 바로 반영 (Release 없이):** 설치된 VM 안에서 `tools\Update-LiteWinFromRepo.ps1`을 실행하면, 설정 앱·셸·맥 단축키·구성요소 관리자 수정분만 바꿔 넣습니다.
  - VMware라면 공유 폴더에 이 저장소를 추가한 뒤, VM의 관리자 PowerShell에서 실행합니다.
    ```powershell
    powershell -ExecutionPolicy Bypass -File "\\vmware-host\Shared Folders\OS\tools\Update-LiteWinFromRepo.ps1" -OpenSettings
    ```
  - 설치 마지막 단계 스크립트(`setup`)를 고쳤다면 `-RunSetup`을 붙입니다.
  - 첫 로그인 직후에 VM 스냅샷을 하나 만들어 두면, 언제든 깨끗한 상태로 돌아가 다시 확인할 수 있습니다.

### 설치 이미지에 미리 넣는 프로그램
빌드할 때 `winget download`로 받습니다. 받은 설치 파일은 winget 매니페스트의 SHA-256 해시로 검증하고, 설치 중에 인터넷 없이 무인 설치합니다.

| 프로그램 | 용도 |
|---|---|
| Google Chrome (기업용 MSI, 서명 확인) | 기본 브라우저 |
| MPC-BE / ImageGlass | 동영상, HEIC 기본 앱 |
| ExplorerPatcher (공식 GitHub 릴리스) | Windows 10 작업표시줄·시작 메뉴 (클래식 기본) |
| RetroBar + .NET 10 데스크톱 런타임 / Open-Shell | Win95~7 작업표시줄(예비), Win7 시작 메뉴 |
| AutoHotkey v2 실행 파일 (설치 안 함) | 맥 입력을 켤 때만 `LiteWinKeys.exe`로 꺼내 씀. 시작 메뉴·앱 목록·트레이 아이콘 없음 |

winget 다운로드가 실패하면 각 프로젝트의 공식 GitHub 릴리스(SHA-256 확인) 또는 Microsoft 공식 링크(서명 확인)에서 받습니다. 그래도 실패한 항목은 건너뛰고, 설치 후 인터넷으로 받습니다.

### 클래식 구조 / 제어판
- **Win10 이전처럼 전체 오른쪽 클릭 메뉴**를 씁니다. Windows 11의 '추가 옵션 표시' 단계가 없습니다.
- 시작 메뉴에 **「클래식 제어판」** 폴더를 둡니다.
  - 프로그램 및 기능, 네트워크 연결, 소리, 마우스, 전원 옵션, 시스템 고급 설정
  - 지역, 날짜 및 시간, 인터넷 옵션, 사용자 계정, 장치 관리자, 디스크 관리
  - 서비스, 고급 방화벽, 작업 스케줄러, 이벤트 뷰어, 장치 및 프린터, 갓 모드
- 제어판 기본 보기는 큰 아이콘이고, 설정 앱의 '홈'(추천·계정 홍보) 페이지는 숨깁니다.
- Microsoft가 클래식 창 자체를 지운 항목(디스플레이, 개인 설정, Windows Update)은 되살릴 수 없습니다.

### 설치 순서
1. USB(또는 VM에 ISO)로 부팅합니다. 설치 화면 배경은 LiteWin 색(짙은 청회색)입니다.
2. 설치할 디스크를 **직접 선택**합니다. 자동 포맷은 없습니다.
3. 파일 복사가 끝나면 마지막 단계에서 Chrome·기본 앱 설치와 Edge 제거가 자동으로 됩니다.
4. Windows 설치 화면은 계정·지역 등을 묻지 않고 넘어가고, `user`로 자동 로그인됩니다. (무선 랜이라면 네트워크 화면에서 연결을 고를 수 있습니다)
5. **LiteWin 마법사**가 뜹니다: 암호 → 계정 종류(Administrator 체크) → 나머지 설정. Administrator를 골랐다면 로그아웃 후 Administrator로 넘어갑니다.
6. LiteWin 설정 > 정보(또는 Windows 설정 > 시스템 > 정품 인증)에서 정품 인증을 확인합니다.

로그는 `C:\ProgramData\LiteWin\logs`에 남습니다.

## 다른 Windows에서 일부 기능만 쓰기
이 저장소 폴더를 통째로 받아 관리자 PowerShell에서 실행하면 됩니다.
```powershell
powershell -ExecutionPolicy Bypass -File .\app\LiteWinSettings.ps1      # 설정 앱 전체
powershell -ExecutionPolicy Bypass -File .\macstyle\Install-MacStyle.ps1 # 맥 입력만
powershell -ExecutionPolicy Bypass -File .\tools\Test-Catalog.ps1        # 앱 ID 확인
```

## 주의
- **아직 실제 설치까지 검증하지는 못했습니다.**
  - GitHub Actions(Windows)에서 PowerShell 문법 검사, C# 프로그램 컴파일, AutoHotkey 스크립트 검사까지는 자동으로 돕니다.
  - 실제 설치와 화면 동작은 가상머신(VMware/Hyper-V/VirtualBox)에서 먼저 확인해 주세요.
- **확실하지 않은 값이 있습니다.**
  - 트랙패드 제스처 값과 일부 winget/Store ID는 정확하지 않을 수 있습니다. `tools\Test-Catalog.ps1`로 앱 ID를 확인할 수 있습니다.
  - 마우스 가속 곡선은 맥을 실측한 값이 아닌 근사치입니다.
- **Edge 제거는 EU 밖 지역에서 Microsoft가 공식 지원하지 않는 방식**입니다.
  - Edge 자체 제거 명령을 쓰며, 큰 업데이트 뒤 Edge가 다시 설치되면 부팅할 때 자동으로 다시 제거합니다.
  - Windows 일부 기능이 Edge 전용 링크를 쓰는데, 이 링크는 Chrome으로 열립니다.
- 만든 ISO는 본인 PC에서만 쓰세요. 수정한 Windows 이미지를 재배포하면 라이선스 위반입니다.
- 맥 앱 실행은 지원하지 않습니다. 이유와 대안은 [docs/mac-apps.md](docs/mac-apps.md)에 정리했습니다.

## 폴더 구조
```
build/      Build-LiteWin.ps1 (빌드), Get-WindowsIso.ps1 (MS 공식 ISO), Offline*.ps1 (오프라인 레지스트리·Edge), SetupBackground.ps1, Compile-LiteWinTools.ps1
profiles/   빌드 프로필 (제거 목록 + 마법사 기본 선택)
unattend/   자동 응답 파일, 작업표시줄 레이아웃
setup/      설치 마지막 단계(SYSTEM) / 첫 로그인 스크립트
app/        LiteWin 설정 앱(마법사·탭), 적용 스크립트, 로그인 시 셸 적용, Edge 감시, 구성요소 업데이트
lib/        공용 함수, 모드, 셸, 앱·브라우저 설치, Edge, 파일 연결, 테마, 정품 인증, 구성요소, LiteWin 업데이트
shell/      자체 프로그램 소스 (설정 실행 파일, 창 버튼, Edge 리다이렉트) — 빌드 때 컴파일
apps/       catalog.json (설치 가능한 앱 목록)
macstyle/   MacKeys.ahk (키보드), 마우스/트랙패드 설정
assets/     배경화면
docs/       맥 UI, 맥 앱 관련 문서
tools/      앱 ID 확인, VM 반영, 업데이트 파일 만들기, 설치 화면 이미지 조사, 정품 인증 복구
.github/    validate(자동 검사), release(온라인 업데이트 배포)
```
