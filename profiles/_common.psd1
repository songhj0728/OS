# 모든 프로필에 공통으로 적용되는 기본값.
# 각 프로필(Standard/Minimal/Gaming)은 이 목록에 Add* 로 추가하고 Keep* 로 예외를 둔다.
# 이름은 "앞부분 일치(prefix)"로 비교한다. 예) 'Microsoft.Xbox' -> Microsoft.XboxGamingOverlay 등 전부.
@{
    # ---- 제거할 기본 앱 (AppX provisioned package) ----
    # 주의: Store, App Installer(winget), VCLibs, UI.Xaml, 보안센터(SecHealthUI),
    #       계산기, 메모장, 그림판, 캡처도구, 터미널은 일부러 넣지 않았다(유지).
    RemoveAppx = @(
        'Clipchamp.Clipchamp'
        'Microsoft.549981C3F5F10'          # Cortana
        'Microsoft.BingNews'
        'Microsoft.BingSearch'
        'Microsoft.BingWeather'
        'Microsoft.Copilot'
        'Microsoft.GetHelp'
        'Microsoft.Getstarted'
        'Microsoft.MicrosoftOfficeHub'
        'Microsoft.MicrosoftSolitaireCollection'
        'Microsoft.MicrosoftStickyNotes'
        'Microsoft.MixedReality.Portal'
        'Microsoft.Office.OneNote'
        'Microsoft.OutlookForWindows'
        'Microsoft.People'
        'Microsoft.PowerAutomateDesktop'
        'Microsoft.SkypeApp'
        'Microsoft.Todos'
        'Microsoft.Wallet'
        'Microsoft.Windows.DevHome'
        'Microsoft.WindowsAlarms'
        'Microsoft.WindowsFeedbackHub'
        'Microsoft.WindowsMaps'
        'Microsoft.WindowsSoundRecorder'
        'Microsoft.YourPhone'
        'Microsoft.ZuneMusic'
        'Microsoft.ZuneVideo'
        'microsoft.windowscommunicationsapps' # 메일/일정
        'MicrosoftCorporationII.MicrosoftFamily'
        'MicrosoftCorporationII.QuickAssist'
        'MicrosoftTeams'
        'MSTeams'
        'Microsoft.Xbox.TCUI'
        'Microsoft.XboxApp'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.GamingApp'
    )

    # ---- 제거할 Windows 기능(Capability, "선택적 기능") ----
    # 언어 관련(Language.*)은 한국어 IME가 깨질 수 있으므로 절대 넣지 않는다.
    RemoveCapabilities = @(
        'Browser.InternetExplorer'
        'MathRecognizer'
        'App.StepsRecorder'
        'App.Support.QuickAssist'
        'Microsoft.Windows.PowerShell.ISE'
        'Microsoft.Windows.WordPad'
        'Microsoft.Wallpapers.Extended'
        'Media.WindowsMediaPlayer'           # 레거시 WMP. 새 '미디어 플레이어' 앱과 별개
    )

    # ---- 끌 Windows 선택적 기능(OptionalFeature) ----
    DisableFeatures = @(
        'Recall'
        'WorkFolders-Client'
        'Printing-XPSServices-Features'
        'MicrosoftWindowsPowerShellV2Root'
        'MicrosoftWindowsPowerShellV2'
    )

    # ---- 설치 후(SetupComplete) 서비스 시작 유형 ----
    DisableServices = @(
        'DiagTrack'          # 원격 분석(Connected User Experiences and Telemetry)
        'dmwappushservice'   # WAP 푸시(원격 분석 라우팅)
        'RetailDemo'
        'MapsBroker'
    )
    ManualServices = @(
        'WerSvc'             # 오류 보고: 필요할 때만
        'lfsvc'              # 위치
        'WpcMonSvc'          # 자녀 보호
        'PcaSvc'             # 프로그램 호환성 도우미
    )

    # ---- 끌 예약 작업 (\경로\이름) ----
    DisableTasks = @(
        '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser'
        '\Microsoft\Windows\Application Experience\ProgramDataUpdater'
        '\Microsoft\Windows\Application Experience\StartupAppTask'
        '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator'
        '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip'
        '\Microsoft\Windows\Autochk\Proxy'
        '\Microsoft\Windows\Feedback\Siuf\DmClient'
        '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
        '\Microsoft\Windows\Windows Error Reporting\QueueReporting'
        '\Microsoft\Windows\Maps\MapsUpdateTask'
        '\Microsoft\Windows\Maps\MapsToastTask'
    )

    # ---- 기타 스위치 ----
    DisableHibernation    = $false   # true면 hiberfil.sys 삭제(디스크 수 GB 절약) + 빠른 시작 꺼짐
    DisableSearchIndexing = $false   # true면 WSearch 비활성(시작메뉴 파일검색/Outlook 검색 느려짐)
    DisableSysMain        = $false   # true면 SysMain(Superfetch) 비활성. SSD에서는 영향 적음
    RemoveOneDrive        = $true    # 새 사용자 첫 로그인 시 OneDrive 자동설치 막기
    MacStyle              = $true    # 맥 스타일 키보드/마우스/트랙패드 적용
    ResetBase             = $true    # 구성요소 정리(/ResetBase). 업데이트는 계속 됨, 단 이전 업데이트 제거 불가
}
