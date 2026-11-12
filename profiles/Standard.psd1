# Standard: 일상/업무용 권장 프로필.
# 공통 제거 목록 그대로. 사진/미디어 플레이어/캡처 도구 등 기본 앱 유지.
@{
    Name        = 'Standard'
    Description = '일상/업무용. 광고·원격분석·번들앱·Office·Edge 제거, 기본 앱과 업데이트는 유지'

    AddRemoveAppx = @()
    KeepAppx      = @()

    AddRemoveCapabilities = @()
    KeepCapabilities      = @()

    AddDisableFeatures = @()

    AddDisableServices = @()
    AddManualServices  = @()
    AddDisableTasks    = @()

    Overrides = @{}

    # 첫 로그인 마법사(LiteWin 설정)에서 미리 선택해 둘 값. 사용자가 바꿀 수 있다.
    #   Mode: Lite | MacInput | MacUI,  Apps: apps\catalog.json 의 id
    Defaults = @{
        Mode      = 'MacInput'
        UiOptions = @()
        Apps      = @()
    }
}
