# Gaming: Standard 와 같은 제거 목록 + 첫 로그인 마법사에서 게임 런처를 미리 선택.
# Xbox 는 기본 해제(옵션). 마법사의 [모두 해제] / [앱 설치 건너뛰기] 로 아무것도 안 깔 수도 있다.
# 맥 키 매핑은 전체화면 게임 중에 자동으로 꺼진다(MacKeys.ahk GameAutoOff).
@{
    Name        = 'Gaming'
    Description = 'Standard + 게임 런처/Discord/그래픽 드라이버를 마법사에서 미리 선택'

    AddRemoveAppx = @()
    KeepAppx      = @()

    AddRemoveCapabilities = @()
    KeepCapabilities      = @()

    AddDisableFeatures = @()

    AddDisableServices = @()
    AddManualServices  = @()
    AddDisableTasks    = @()

    Overrides = @{}

    Defaults = @{
        Mode      = 'MacInput'
        UiOptions = @()
        Apps      = @('steam', 'epic', 'discord', 'gpu-driver')
    }
}
