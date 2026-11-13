<#
.SYNOPSIS LiteWin 자체 프로그램(shell\*.cs)을 .NET Framework 내장 컴파일러로 빌드한다. (빌드 스크립트와 CI 가 공용으로 사용)
    LiteWinEdgeRedirect.exe  : Edge 전용 링크 → 기본 브라우저 (상주 안 함)
    LiteWinCaption.exe       : 모든 창에 맥식 창 버튼 (맥 UI 모드)
    LiteWinSettings.exe      : LiteWin 설정을 콘솔 없이 관리자 권한으로 바로 열기
.OUTPUTS 실패한 도구 이름 목록 (없으면 빈 배열)
#>
param([Parameter(Mandatory)][string]$OutDir, [switch]$FailFast)

$repo = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$adminManifest = @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">
  <assemblyIdentity version="1.0.0.0" name="LiteWin.Settings"/>
  <trustInfo xmlns="urn:schemas-microsoft-com:asm.v2">
    <security><requestedPrivileges>
      <requestedExecutionLevel level="requireAdministrator" uiAccess="false"/>
    </requestedPrivileges></security>
  </trustInfo>
  <application xmlns="urn:schemas-microsoft-com:asm.v3">
    <windowsSettings>
      <dpiAware xmlns="http://schemas.microsoft.com/SMI/2005/WindowsSettings">true/pm</dpiAware>
      <dpiAwareness xmlns="http://schemas.microsoft.com/SMI/2016/WindowsSettings">PerMonitorV2</dpiAwareness>
    </windowsSettings>
  </application>
</assembly>
'@

$tools = @(
    @{ Src = 'shell\EdgeRedirect.cs';            Out = 'LiteWinEdgeRedirect.exe'; Refs = @();                                       Manifest = $null }
    @{ Src = 'shell\LiteWinCaption.cs';          Out = 'LiteWinCaption.exe';      Refs = @('System.Windows.Forms.dll', 'System.Drawing.dll'); Manifest = $null }
    @{ Src = 'shell\LiteWinSettingsLauncher.cs'; Out = 'LiteWinSettings.exe';     Refs = @('System.Windows.Forms.dll', [psobject].Assembly.Location); Manifest = $adminManifest }
)

$failed = @()
foreach ($t in $tools) {
    try {
        $cp = New-Object System.CodeDom.Compiler.CompilerParameters
        $cp.GenerateExecutable = $true
        $cp.OutputAssembly = Join-Path $OutDir $t.Out
        $cp.TreatWarningsAsErrors = $false
        $cp.WarningLevel = 0          # (-IgnoreWarnings 는 -CompilerParameters 와 같이 쓸 수 없음)
        $cp.ReferencedAssemblies.Add('System.dll') | Out-Null
        $cp.ReferencedAssemblies.Add('System.Core.dll') | Out-Null   # HashSet, System.Dynamic (PowerShell 호스팅)
        foreach ($r in $t.Refs) { $cp.ReferencedAssemblies.Add($r) | Out-Null }
        $opts = '/target:winexe /optimize+'
        if ($t.Manifest) {
            $mf = Join-Path $env:TEMP ("litewin-{0}.manifest" -f [guid]::NewGuid().ToString('N'))
            Set-Content -Path $mf -Value $t.Manifest -Encoding UTF8
            $opts += " /win32manifest:`"$mf`""
        }
        $cp.CompilerOptions = $opts
        $src = Get-Content (Join-Path $repo $t.Src) -Raw -Encoding UTF8
        Add-Type -TypeDefinition $src -CompilerParameters $cp -ErrorAction Stop
        Write-Host "    $($t.Out) 컴파일"
    } catch {
        Write-Host "    ! $($t.Out) 컴파일 실패: $($_.Exception.Message)" -ForegroundColor Yellow
        $failed += $t.Out
        if ($FailFast) { throw }
    }
}
return , $failed
