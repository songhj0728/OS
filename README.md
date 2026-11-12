# LiteWin: 가볍고 맥처럼 쓰는 Windows 11 Pro

공식 Windows 11 ISO를 바탕으로 **가벼운 Pro 설치 USB/ISO**를 직접 만드는 스크립트 모음입니다.
**맥 스타일 입력**(키보드 단축키, 마우스 가속, 트랙패드 제스처)도 함께 적용합니다.

- 커널과 시스템은 진짜 Windows 11 그대로입니다. 그래서 일반 프로그램, 드라이버, 게임, 은행·보안 프로그램이 똑같이 돌아갑니다.
- 32비트 프로그램은 WOW64로 그대로 실행됩니다. 32비트 프로그램을 실행할 때만 관련 구성요소가 메모리에 올라오고, 평소에는 메모리를 쓰지 않습니다.
- 정품 인증은 **본인의 Pro 라이선스**로 합니다. 디지털 라이선스는 자동으로 인식되고, 키가 있다면 설치 후 설정에서 입력하면 됩니다.
- tiny11처럼 시스템 파일을 강제로 지우지 않습니다. 그래서 **Windows Update, 기능 추가, sfc/DISM 복구가 정상 동작**합니다.

## 무엇이 빠지고 무엇이 남나

| 빠짐 | 남음 |
|---|---|
| Copilot, Recall, 위젯, Teams/Outlook 자동설치 | Windows Update, Defender, 방화벽 |
| 광고·추천·시작메뉴 프로모션, 원격분석(최소 수준) | Microsoft Store, winget(App Installer) |
| Bing 웹검색(시작메뉴 검색은 로컬만) | Edge/WebView2(많은 앱이 의존함) |
| Clipchamp, 뉴스, 날씨, 솔리테어, 지도, 피드백 허브 등 번들앱 | 계산기, 메모장, 그림판, 캡처도구, 터미널, 사진* |
| IE 모드, 수학 입력판, PowerShell 2.0, 레거시 WMP 등 | .NET, Visual C++ 런타임, 한국어 IME, 드라이버 저장소 |
| OneDrive 자동설치(새 계정) | 32비트 실행(WOW64) |

\* Minimal 프로필은 사진, 카메라, 위젯 런타임까지 뺍니다.

### 프로필

| 프로필 | 용도 | 특징 |
|---|---|---|
| **Standard** (기본) | 일상/업무 | 위 표의 기본값 |
| **Minimal** | 저사양, 단일 용도 PC | 검색 색인, 최대 절전(hiberfil), SysMain 끔 + 기본앱 더 제거 |
| **Gaming** | 게임 | Standard 구성에 Xbox 앱, 게임 바, Xbox 로그인 유지 |

목록은 `profiles/*.psd1`에서 직접 고칠 수 있습니다. 앱/기능 이름은 앞부분만 일치해도 처리되고, Keep 목록에 넣으면 제거 대상에서 빠집니다.

## 맥 스타일

PC 키보드 왼쪽 아래 배열을 맥 위치 그대로 해석합니다. **왼쪽 Alt = ⌘**, **왼쪽 Win = ⌥** 입니다.

| 맥 | 동작 |
|---|---|
| ⌘C / ⌘V / ⌘X / ⌘Z / ⌘⇧Z | 복사 / 붙여넣기 / 잘라내기 / 실행 취소 / 다시 실행 (터미널에서는 Ctrl+Shift+C/V) |
| ⌘A, ⌘S, ⌘F, ⌘T, ⌘⇧T, ⌘W, ⌘N, ⌘P, ⌘1~9 | 각각 같은 기능 |
| ⌘Q / ⌘H / ⌘M | 앱 종료 / 숨기기 / 최소화 |
| ⌘Tab | 앱 전환(Alt+Tab) |
| ⌘Space | 검색(Spotlight) |
| ⌘←/→, ⌘↑/↓ | 줄 처음/끝, 문서 처음/끝 (⇧를 같이 누르면 선택) |
| ⌥←/→, ⌥⌫ | 단어 단위 이동/삭제 |
| ⌘⌫ | 줄 앞까지 삭제 |
| ⌘⇧3 / ⌘⇧4 / ⌘⇧5 | 전체 스크린샷 / 영역 캡처 / 화면 녹화 |
| ⌃⌘F / ⌃⌘Q / ⌘⌥Esc | 전체화면 / 화면 잠금 / 작업 관리자 |
| ⌃⌘←/→/↑/↓ | 창 스냅 (원래 Win+방향키) |
| **Caps Lock** | 짧게 누르면 **한/영 전환**, 길게 누르면 Caps Lock |

- **마우스**: 맥처럼 천천히 움직이면 더 정밀하고, 빠르게 움직이면 더 멀리 가는 가속 곡선입니다. 휠 방향은 자연스러운 스크롤(맥 방식)로 바꿉니다.
- **트랙패드**(정밀 터치패드):
  - 두 손가락 탭 = 우클릭, 오른쪽 아래 모서리 우클릭 끔
  - 자연스러운 스크롤, 핀치 줌
  - 세 손가락 좌우 = 데스크톱(Spaces) 전환, 세 손가락 위 = 작업 보기(Mission Control)
- **잠시 끄기**: `Ctrl + Alt + Win + F12`. 게임이나 원격 데스크톱처럼 매핑하면 안 되는 프로그램은 `MacKeys.ahk`의 `NoRemap` 목록에 넣으면 자동으로 꺼집니다.
- 단축키는 AutoHotkey v2(메모리 약 2~4MB)로 동작합니다. 로그인할 때 관리자 권한으로 자동 실행되므로 관리자 창에서도 동작합니다.

이미 설치된 일반 Windows에서도 맥 스타일만 따로 쓸 수 있습니다.
```powershell
# 관리자 PowerShell
powershell -ExecutionPolicy Bypass -File .\macstyle\Install-MacStyle.ps1
# 되돌리기
powershell -ExecutionPolicy Bypass -File .\macstyle\Uninstall-MacStyle.ps1
```
> 맥북에 Boot Camp로 설치했다면, 트랙패드 제스처를 쓰려면 정밀 터치패드 드라이버(오픈소스 `mac-precision-touchpad`)가 필요합니다.

## 만드는 방법

### 준비물
1. Windows 10/11 PC 한 대 (빌드용. 설치할 PC와 같아도 됨)
2. 공식 Windows 11 ISO: <https://www.microsoft.com/software-download/windows11> (한국어 x64)
3. ISO 생성 도구 oscdimg: `winget install Microsoft.WindowsADK`를 실행한 뒤 **배포 도구(Deployment Tools)** 만 선택
   - 이 단계가 번거롭다면 `-NoIso`로 폴더까지만 만들고 [Rufus](https://rufus.ie)로 USB를 만들어도 됩니다.
4. 여유 공간 약 25GB

### 빌드
```powershell
# 관리자 권한 "Windows PowerShell"에서 이 저장소 폴더로 이동한 뒤 실행
Set-ExecutionPolicy -Scope Process Bypass
.\build\Build-LiteWin.ps1 -IsoPath D:\Win11_24H2_Korean_x64.iso
# 다른 프로필
.\build\Build-LiteWin.ps1 -IsoPath D:\Win11.iso -ProfileName Minimal
```
결과물은 `out\LiteWin-Standard.iso`이고, 보통 20~40분 걸립니다. 자주 쓰는 옵션은 다음과 같습니다.

| 옵션 | 설명 |
|---|---|
| `-ProfileName Standard\|Minimal\|Gaming` | 프로필 |
| `-SplitForFat32` | install.wim이 4GB를 넘으면 분할 (FAT32 USB용) |
| `-NoIso` | `C:\LiteWinWork\iso` 폴더까지만 만듦 |
| `-BypassHardwareCheck` | TPM 2.0, 보안 부팅, CPU 검사 우회. 지원되지 않는 PC용이며, MS가 업데이트를 보장하지 않음 |
| `-Locale`, `-InputLocale`, `-TimeZone` | 기본값은 한국어, 한국어 IME, 한국 표준시 |

### 설치
1. ISO를 USB로 굽습니다. Rufus를 쓰거나, Ventoy USB에 ISO 파일을 복사하면 됩니다.
2. USB로 부팅합니다. 언어 선택과 약관 화면은 자동으로 넘어갑니다.
3. 설치할 디스크는 **직접 선택**합니다. 실수로 다른 디스크를 지우지 않도록 자동 포맷은 넣지 않았습니다.
4. 계정 화면에서 **로컬 계정**을 만듭니다. MS 계정 강제 화면은 나오지 않습니다.
5. 첫 로그인 때 맥 스타일이 자동으로 설치됩니다. 인터넷이 없으면 바탕화면에 생기는 **「맥 스타일 설치」** 바로가기를 나중에 실행하면 됩니다.
6. **설정 > 시스템 > 정품 인증**에서 Pro 정품 인증 상태를 확인합니다. 같은 PC에서 예전에 인증한 적이 있다면 자동으로 인증됩니다.

로그는 `C:\ProgramData\LiteWin\logs`에 남습니다.

## 얼마나 가벼워지나 (대략)

| | 기본 Win11 Pro | LiteWin Standard | LiteWin Minimal |
|---|---|---|---|
| 설치 후 디스크 | 약 25~30GB | 약 15~18GB | 약 12~15GB |
| 부팅 직후 RAM | 약 2.5~3.5GB | 약 1.5~2GB | 약 1.2~1.6GB |
| 백그라운드 프로세스 | 약 130~160개 | 약 90~110개 | 약 70~90개 |

이 수치는 하드웨어, 드라이버, 빌드 버전에 따라 크게 달라지는 참고값이고, 실제로 측정한 값이 아닙니다. 첫 업데이트 직후에는 일시적으로 더 무거울 수 있습니다.

## 주의
- 만든 ISO는 **본인 PC용**입니다. 수정한 Windows 이미지를 재배포하면 라이선스 위반입니다.
- 이 스크립트는 Linux 환경에서 작성되어 아직 실제 Windows에서 빌드해 보지 않았습니다. 처음에는 **가상머신(Hyper-V/VirtualBox)에서 먼저 설치해 보는 것**을 권장합니다.
- 제거한 앱은 대부분 Store나 winget으로 다시 설치할 수 있습니다.

## 폴더 구조
```
build/Build-LiteWin.ps1        ISO 빌드 메인 스크립트
build/OfflineTweaks.ps1        오프라인 레지스트리 정책 목록
profiles/*.psd1                제거/비활성 목록 (프로필)
unattend/autounattend.template.xml   자동 응답 파일 템플릿
setup/                         설치 중(SetupComplete)·첫 로그인(FirstLogon) 스크립트
macstyle/                      맥 스타일 키보드(AHK)/마우스/트랙패드
```

## FAQ
**Q. 아예 처음부터 가벼운 OS를 만들면 안 되나요?**
x86-64 부팅 커널 자체는 만들 수 있습니다. 하지만 그 위에서 기존 Windows 프로그램을 돌리려면 Win32 API, 드라이버 모델, DirectX를 전부 다시 구현해야 합니다. ReactOS가 25년 넘게 이 작업을 하고 있지만 아직 알파 단계입니다. "프로그램 구동에 문제없는" 수준이 목표라면 Windows 커널을 그대로 두고 껍데기를 덜어내는 이 방식이 사실상 유일한 길입니다.
