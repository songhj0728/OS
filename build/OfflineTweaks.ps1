<#
    마운트된 이미지의 오프라인 레지스트리에 넣을 값들.
    Hive: SOFTWARE / SYSTEM  = HKLM 쪽,  NTUSER = 새 사용자 기본값(Default 프로필)
    모두 공식 그룹 정책/설정 값이며 "파일 삭제"는 하지 않는다 → 업데이트/복구가 깨지지 않음.
#>

$script:OfflineRegTweaks = @(
    # ---------- 원격 분석 / 광고 ----------
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\DataCollection'; Name='AllowTelemetry'; Type='DWord'; Value=0 } # Pro 에선 실제로 '필수'(1) 수준으로 동작
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\DataCollection'; Name='DoNotShowFeedbackNotifications'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\AdvertisingInfo'; Name='DisabledByGroupPolicy'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\CloudContent'; Name='DisableWindowsConsumerFeatures'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\CloudContent'; Name='DisableConsumerAccountStateContent'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\CloudContent'; Name='DisableCloudOptimizedContent'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\System'; Name='PublishUserActivities'; Type='DWord'; Value=0 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\System'; Name='EnableActivityFeed'; Type='DWord'; Value=0 }

    # ---------- Copilot / Recall / 위젯 / Teams 자동설치 ----------
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\WindowsAI'; Name='DisableAIDataAnalysis'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\WindowsAI'; Name='AllowRecallEnablement'; Type='DWord'; Value=0 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Dsh'; Name='AllowNewsAndInterests'; Type='DWord'; Value=0 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\Windows Chat'; Name='ChatIcon'; Type='DWord'; Value=3 }
    @{ Hive='NTUSER';   Path='Software\Policies\Microsoft\Windows\WindowsCopilot'; Name='TurnOffWindowsCopilot'; Type='DWord'; Value=1 }

    # ---------- 검색: 웹 결과/Bing 끄기 (로컬 검색만, 훨씬 빠름) ----------
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\Windows Search'; Name='AllowCortana'; Type='DWord'; Value=0 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\Windows Search'; Name='DisableWebSearch'; Type='DWord'; Value=1 }
    @{ Hive='SOFTWARE'; Path='Policies\Microsoft\Windows\Windows Search'; Name='ConnectedSearchUseWeb'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER';   Path='Software\Policies\Microsoft\Windows\Explorer'; Name='DisableSearchBoxSuggestions'; Type='DWord'; Value=1 }

    # ---------- 설치(OOBE): 로컬 계정 허용 ----------
    @{ Hive='SOFTWARE'; Path='Microsoft\Windows\CurrentVersion\OOBE'; Name='BypassNRO'; Type='DWord'; Value=1 }

    # ---------- 서비스(오프라인으로 미리 끔) ----------
    @{ Hive='SYSTEM'; Path='ControlSet001\Services\DiagTrack'; Name='Start'; Type='DWord'; Value=4 }
    @{ Hive='SYSTEM'; Path='ControlSet001\Services\dmwappushservice'; Name='Start'; Type='DWord'; Value=4 }

    # ---------- 새 사용자 기본값: 추천/광고/자동설치 앱 끔 ----------
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='ContentDeliveryAllowed'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='FeatureManagementEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='OemPreInstalledAppsEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='PreInstalledAppsEverEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SilentInstalledAppsEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SoftLandingEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SystemPaneSuggestionsEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-310093Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338388Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338389Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-338393Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353694Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353696Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'; Name='SubscribedContent-353698Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo'; Name='Enabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Privacy'; Name='TailoredExperiencesWithDiagnosticDataEnabled'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement'; Name='ScoobeSystemSettingEnabled'; Type='DWord'; Value=0 } # "설정 마무리" 팝업

    # ---------- 탐색기/작업표시줄 (맥 Dock 처럼 가운데 정렬은 기본값 유지) ----------
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='HideFileExt'; Type='DWord'; Value=0 }   # 확장자 보이기
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='LaunchTo'; Type='DWord'; Value=1 }      # 탐색기 = 내 PC
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarDa'; Type='DWord'; Value=0 }     # 위젯 버튼
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarMn'; Type='DWord'; Value=0 }     # 채팅 버튼
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='ShowCopilotButton'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_IrisRecommendations'; Type='DWord'; Value=0 } # 시작메뉴 추천 광고
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Search'; Name='SearchboxTaskbarMode'; Type='DWord'; Value=1 }  # 검색은 아이콘만
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Search'; Name='BingSearchEnabled'; Type='DWord'; Value=0 }
)

# 클래식 구조 / 제어판 우선 / LiteWin 셸 실행
$script:OfflineRegTweaks += @(
    # Win10 이전처럼 전체 오른쪽 클릭 메뉴 (Windows 11 '추가 옵션 표시' 단계 없앰)
    @{ Hive='NTUSER'; Path='Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'; Name='(default)'; Type='String'; Value='' }
    # 제어판: 큰 아이콘으로 모든 항목 바로 보기
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel'; Name='AllItemsIconView'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\ControlPanel'; Name='StartupPage'; Type='DWord'; Value=1 }
    # 작업표시줄 기본: 왼쪽 정렬, 단추는 아이콘만(펼쳐 보기는 LiteWin 설정의 옵션)
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='TaskbarAl'; Type='DWord'; Value=0 }
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name='Start_TrackDocs'; Type='DWord'; Value=1 }
    # ExplorerPatcher 기본값(새 사용자): Win10 작업표시줄, 자체 업데이트 알림 끔(LiteWin 이 관리)
    @{ Hive='NTUSER'; Path='Software\ExplorerPatcher'; Name='OldTaskbar'; Type='DWord'; Value=2 }
    @{ Hive='NTUSER'; Path='Software\ExplorerPatcher'; Name='UpdatePolicy'; Type='DWord'; Value=2 }
    # 설정 앱 '홈'(추천/계정 홍보) 페이지 숨김
    @{ Hive='SOFTWARE'; Path='Microsoft\Windows\CurrentVersion\Policies\Explorer'; Name='SettingsPageVisibility'; Type='String'; Value='hide:home' }
    # 로그인할 때마다 LiteWin 셸(클래식 작업표시줄/시작 메뉴/창 버튼) 적용
    @{ Hive='SOFTWARE'; Path='Microsoft\Windows\CurrentVersion\Run'; Name='LiteWinShell'; Type='String'
       Value='powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\ProgramData\LiteWin\app\Start-LiteWinShell.ps1"' }
)

# 존재하면 삭제할 키 (24H2: 설치 직후 Outlook/DevHome 을 몰래 다시 까는 예약)
$script:OfflineRegDeleteKeys = @(
    @{ Hive='SOFTWARE'; Path='Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\OutlookUpdate' }
    @{ Hive='SOFTWARE'; Path='Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe\DevHomeUpdate' }
)

# 존재하면 삭제할 값
$script:OfflineRegDeleteValues = @(
    @{ Hive='NTUSER'; Path='Software\Microsoft\Windows\CurrentVersion\Run'; Name='OneDriveSetup'; Profile='RemoveOneDrive' }
)

# 하드웨어 검사 우회(-BypassHardwareCheck 일 때만). 지원되지 않는 PC 는 MS 가 업데이트를 보장하지 않음
$script:OfflineRegBypass = @(
    @{ Hive='SYSTEM'; Path='Setup\MoSetup'; Name='AllowUpgradesWithUnsupportedTPMOrCPU'; Type='DWord'; Value=1 }
    @{ Hive='SYSTEM'; Path='Setup\LabConfig'; Name='BypassTPMCheck'; Type='DWord'; Value=1 }
    @{ Hive='SYSTEM'; Path='Setup\LabConfig'; Name='BypassSecureBootCheck'; Type='DWord'; Value=1 }
    @{ Hive='SYSTEM'; Path='Setup\LabConfig'; Name='BypassRAMCheck'; Type='DWord'; Value=1 }
    @{ Hive='SYSTEM'; Path='Setup\LabConfig'; Name='BypassCPUCheck'; Type='DWord'; Value=1 }
)
