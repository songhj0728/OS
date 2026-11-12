# Gaming: Standard 기반 + Xbox/게임 관련 구성요소 유지.
# (Game Pass, Xbox 로그인이 필요한 게임, 게임 바 녹화 등)
# 맥 스타일 키 매핑은 MacKeys.ahk 의 NoRemap 그룹에 게임 exe를 넣어 게임 중에는 꺼지게 할 수 있다.
@{
    Name        = 'Gaming'
    Description = 'Standard + Xbox 앱/게임바/로그인 유지'

    AddRemoveAppx = @()
    KeepAppx      = @(
        'Microsoft.Xbox.TCUI'
        'Microsoft.XboxApp'
        'Microsoft.XboxGameOverlay'
        'Microsoft.XboxGamingOverlay'
        'Microsoft.XboxSpeechToTextOverlay'
        'Microsoft.GamingApp'
    )

    AddRemoveCapabilities = @()
    KeepCapabilities      = @()

    AddDisableFeatures = @()

    AddDisableServices = @()
    AddManualServices  = @()
    AddDisableTasks    = @()

    Overrides = @{}
}
