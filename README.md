# LiteWin: 가볍게, 필요하면 맥처럼 쓰는 Windows 11 Pro

**Microsoft 공식 ISO**를 내 PC에서 직접 가공해 가벼운 Pro 설치 USB/ISO를 만드는 스크립트입니다.
설치한 뒤에는 **「LiteWin 설정」** 앱에서 **라이트 윈도우 ↔ 맥 입력 ↔ 맥 입력+UI** 모드를 언제든 오갈 수 있습니다.

- **커널과 시스템은 진짜 Windows 11 그대로입니다.** 일반 프로그램, 드라이버, 게임, 안티치트, 은행·보안 프로그램이 똑같이 동작합니다.
- **32비트 프로그램은 WOW64로 그대로 실행됩니다.** 32비트 프로그램을 켤 때만 메모리를 씁니다.
- **ISO는 Microsoft에서 직접 받습니다.** LiteWin은 수정한 Windows를 배포하지 않습니다. 정품 인증은 **본인 Pro 라이선스**로 합니다.
- **시스템 파일을 강제로 지우지 않습니다.** tiny11과 달리 Windows Update와 sfc/DISM 복구가 정상 동작합니다.

## 무엇이 빠지고 무엇이 남나

| 빠짐 | 남음 / 대체 |
|---|---|
| **Edge 브라우저** (화면 어디에도 안 보임) | **WebView2 런타임 유지**: 앱 화면 표시용이라 게임 런처, Discord, 위젯 등이 필요로 함 |
| Edge 전용 링크(`microsoft-edge:`) | **Chrome으로 자동 연결** (작은 리다이렉트 프로그램, 상주 안 함) |
| — | **Google Chrome = 기본 브라우저** (설치 이미지에 포함, 작업표시줄 고정) |
| Office 계열 (Microsoft 365, OneNote, Outlook) | — |
| Copilot, Recall, 위젯, Teams 자동설치, 광고·추천, Bing 웹검색 | Windows Update, Defender, 방화벽 |
| Clipchamp, 뉴스, 날씨, 솔리테어, 지도, 영화 및 TV 등 | **사진, 미디어 플레이어**, 캡처 도구, 계산기, 메모장, 그림판, 터미널 |
| Xbox 앱 일체 (게임 탭에서 다시 설치 가능) | Microsoft Store, winget, 한국어 IME, .NET, VC++ 런타임 |

Edge를 다시 쓰고 싶으면 LiteWin 설정 > 브라우저에서 체크를 해제하면 다시 설치됩니다.

### 빌드 프로필
빌드 프로필은 **이미지에서 무엇을 지울지**와 **첫 로그인 마법사에서 미리 체크해 둘 항목**만 정합니다. 나머지는 설치 후 바꿀 수 있습니다.

| 프로필 | 특징 | 마법사 기본 선택 |
|---|---|---|
| **Standard** (기본) | 위 표 그대로 | 맥 입력 |
| **Minimal** | 카메라·위젯까지 제거, 검색 색인·최대 절전·SysMain 끔 | 라이트 윈도우 |
| **Gaming** | Standard와 같은 제거 범위 | 맥 입력 + Steam, Epic, Discord, GPU 드라이버 |

## 「LiteWin 설정」 앱 (시작 메뉴, 첫 로그인 때 자동 실행)
창은 열었을 때만 실행됩니다. 모든 탭은 선택 사항이며, **[앱 설치 건너뛰기]** 와 게임 탭의 **[모두 해제]** 로 아무것도 설치하지 않을 수 있습니다.

### 모드

| 모드 | 내용 | 상주 메모리 |
|---|---|---|
| 라이트 윈도우 | 일반 Windows 조작 | 0 |
| 맥 입력 | 키보드(⌘/⌥, Caps Lock=한/영), 맥 마우스 가속, 휠 방향, 트랙패드 제스처 | 약 3MB |
| 맥 입력 + UI | 위 기능에 더해 다크 모드, 작업표시줄 자동 숨김, 투명 효과, QuickLook, Flow Launcher, Windhawk Dock 중 선택 | 고른 항목에 따라 0~200MB |

라이트 윈도우로 돌아가면 **맥 스타일을 처음 켜기 전의 값**으로 복원됩니다. UI 상세 설명은 [docs/mac-ui.md](docs/mac-ui.md)에 있습니다.

### 사진·동영상
기본은 Windows 사진 앱과 미디어 플레이어입니다. 더 많은 형식이 필요할 때만 고르면 됩니다.

| 옵션 | 내용 |
|---|---|
| **무료 코덱 확장 팩** | VP9, AV1, HEIF(아이폰 .heic), 카메라 RAW, WebP, MPEG-2. 기본 앱과 탐색기 미리보기에 함께 적용되고 상주 메모리는 0 |
| HEVC 확장 | 유료(약 1,000원)라 Store 페이지만 엽니다. MPC-BE를 쓰면 필요 없음 |
| **ImageGlass** | EXIF 정보 패널, 80여 개 이미지 형식 |
| **MPC-BE** | 코덱 설치 없이 VP9, AV1, HEVC, 10bit, HDR, MKV 재생 |

### 게임 (모두 옵션)
- **플랫폼**: Xbox(앱, 게임 바, 로그인), Steam, Epic Games, Battle.net, EA app, Ubisoft Connect, GOG Galaxy, 리그 오브 레전드, 발로란트, Rockstar, Minecraft, Playnite
- **커뮤니티·브라우저**: Discord, **Discord Phoenix(Rust 네이티브)**, Opera GX
  - Phoenix는 현재 공개 베타 배포 경로가 없어 회색으로 표시됩니다. 배포가 시작되면 `apps/catalog.json`에 패키지 ID만 넣으면 활성화됩니다.
- **드라이버**: GPU 제조사(NVIDIA, AMD, Intel)를 자동 감지해 공식 드라이버 페이지를 엽니다.
- 발로란트(Vanguard)는 TPM 2.0과 보안 부팅이 필요합니다. 조건이 맞지 않는 PC에서는 경고를 표시합니다.
- 맥 단축키는 **전체화면 게임 중 자동으로 꺼집니다.**

## 맥 입력 단축키
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
| Ctrl+Alt+Win+F12 | 단축키 잠시 끄기/켜기 |

## 만드는 방법
준비물은 다음과 같습니다.
- Windows 10/11 PC와 관리자 권한 **Windows PowerShell**
- 인터넷 연결
- 여유 공간 약 25GB
- **oscdimg**: `winget install Microsoft.WindowsADK`를 실행한 뒤 "배포 도구"만 선택합니다. 이 단계 대신 `-NoIso`로 폴더까지만 만들고 Rufus로 USB를 만들어도 됩니다.

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\build\Build-LiteWin.ps1                          # ISO를 Microsoft에서 직접 받아 빌드
.\build\Build-LiteWin.ps1 -IsoPath D:\Win11.iso    # 이미 받은 공식 ISO 사용
.\build\Build-LiteWin.ps1 -ProfileName Gaming
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

### 설치 순서
1. USB로 부팅합니다.
2. 설치할 디스크를 **직접 선택**합니다. 자동 포맷은 없습니다.
3. 로컬 계정을 만듭니다.
4. 설치 마지막 단계에서 Chrome 설치와 Edge 제거가 자동으로 진행됩니다.
5. 첫 로그인 후 **LiteWin 시작하기** 마법사가 뜹니다.
6. 설정 > 시스템 > 정품 인증에서 Pro 정품 인증 상태를 확인합니다.

로그는 `C:\ProgramData\LiteWin\logs`에 남습니다.

## 다른 Windows에서 일부 기능만 쓰기
이 저장소 폴더를 통째로 받아 관리자 PowerShell에서 실행하면 됩니다.
```powershell
powershell -ExecutionPolicy Bypass -File .\app\LiteWinSettings.ps1      # 설정 앱 전체
powershell -ExecutionPolicy Bypass -File .\macstyle\Install-MacStyle.ps1 # 맥 입력만
powershell -ExecutionPolicy Bypass -File .\tools\Test-Catalog.ps1        # 앱 ID 확인
```

## 주의
- **아직 실제 Windows에서 실행 검증을 하지 못했습니다.** 이 저장소는 Linux 환경에서 작성되었습니다. 먼저 가상머신(Hyper-V/VirtualBox)에서 설치해 보세요.
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
build/      Build-LiteWin.ps1 (빌드), Get-WindowsIso.ps1 (MS 공식 ISO 다운로드), OfflineTweaks.ps1
profiles/   빌드 프로필 (제거 목록 + 마법사 기본 선택)
unattend/   자동 응답 파일, 기본 앱 연결(Chrome), 작업표시줄 레이아웃
setup/      설치 마지막 단계(SYSTEM) / 첫 로그인 스크립트
app/        LiteWin 설정 앱(GUI), 적용 스크립트, Edge 감시 작업
lib/        공용 함수, 모드 전환, 앱 설치, Edge 제거·리다이렉트
apps/       catalog.json (설치 가능한 앱 목록)
macstyle/   MacKeys.ahk (키보드), 마우스/트랙패드 설정
docs/       맥 UI, 맥 앱 관련 문서
tools/      Test-Catalog.ps1
```
