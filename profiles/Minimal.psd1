# Minimal: 최대한 가볍게. 저사양 PC/특정 업무 전용 PC용.
# 빠지는 것: 카메라, 위젯, 얼굴인식, 팩스/스캔, 검색 색인, 최대절전 등.
# 사진/미디어 플레이어, Store, winget(App Installer)은 남긴다.
@{
    Name        = 'Minimal'
    Description = '최소 구성. 기본 앱 대부분 제거, 검색 색인/최대절전/SysMain 끔'

    AddRemoveAppx = @(
        'Microsoft.WindowsCamera'
        'Microsoft.Windows.Ai.Copilot.Provider'
        'Microsoft.WidgetsPlatformRuntime'
        'MicrosoftWindows.Client.WebExperience' # 위젯
    )
    KeepAppx = @()

    AddRemoveCapabilities = @(
        'Hello.Face'
        'Print.Fax.Scan'
        'Microsoft.Windows.Notepad.System'    # 레거시 메모장(새 메모장 앱은 유지)
        'Microsoft.Windows.MSPaint'           # 레거시 그림판(새 그림판 앱은 유지)
        'OneCoreUAP.OneSync'
    )
    KeepCapabilities = @()

    AddDisableFeatures = @()

    AddDisableServices = @(
        'Fax'
        'WpcMonSvc'
    )
    AddManualServices = @(
        'TabletInputService'   # 터치키보드/펜이 없으면 수동으로
    )
    AddDisableTasks = @()

    Overrides = @{
        DisableHibernation    = $true
        DisableSearchIndexing = $true
        DisableSysMain        = $true
    }

    Defaults = @{
        Mode      = 'Lite'
        UiOptions = @()
        Apps      = @()
    }
}
