<#
    LiteWin 공용 함수 (로그, 레지스트리, 스냅샷, winget, 상태 파일)
    설치된 PC 에서는 C:\ProgramData\LiteWin\lib 에 있고, 저장소에서도 같은 상대 경로로 동작한다.
#>

$script:LWRoot    = Join-Path $env:ProgramData 'LiteWin'
$script:LWUserDir = Join-Path $env:LOCALAPPDATA 'LiteWin'
$script:LWLogDir  = Join-Path $script:LWRoot 'logs'

function Write-LWLog {
    param([string]$Message, [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO', [string]$File = 'LiteWin.log')
    $line = '{0:yyyy-MM-dd HH:mm:ss} [{1}] {2}' -f (Get-Date), $Level, $Message
    try {
        if (-not (Test-Path $script:LWLogDir)) { New-Item -ItemType Directory -Path $script:LWLogDir -Force | Out-Null }
        Add-Content -Path (Join-Path $script:LWLogDir $File) -Value $line -Encoding UTF8
    } catch { }
    $color = @{ INFO = 'Gray'; WARN = 'Yellow'; ERROR = 'Red' }[$Level]
    Write-Host $line -ForegroundColor $color
}

function Test-LWAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ------------------------------------------------------------------ 레지스트리
function Set-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()]$Value,
        [ValidateSet('String', 'DWord', 'QWord', 'Binary', 'ExpandString', 'MultiString')]
        [string]$Type = 'DWord'
    )
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Get-RegValueEntry {
    <# 값과 종류를 함께 읽는다. 없으면 $null #>
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $key = Get-Item -LiteralPath $Path
    if ($key.GetValueNames() -notcontains $Name) { return $null }
    $kind  = $key.GetValueKind($Name).ToString()
    $value = $key.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
    if ($kind -eq 'Binary') { $value = [Convert]::ToBase64String([byte[]]$value) }
    [pscustomobject]@{ Type = $kind; Value = $value }
}

# ------------------------------------------------------------------ 스냅샷 (모드 되돌리기용)
#   처음 맥 스타일을 켜기 직전의 값을 사용자별로 한 번만 저장해 두고, '라이트 윈도우'로 돌아갈 때 복원한다.
function Save-RegSnapshot {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][object[]]$Entries, [switch]$Force)
    $file = Join-Path $script:LWUserDir "snapshot-$Name.json"
    if ((Test-Path $file) -and -not $Force) { return }   # 최초 상태를 덮어쓰지 않음
    New-Item -ItemType Directory -Path $script:LWUserDir -Force | Out-Null
    $data = foreach ($e in $Entries) {
        $cur = Get-RegValueEntry -Path $e.Path -Name $e.Name
        [pscustomobject]@{
            Path   = $e.Path
            Name   = $e.Name
            Exists = [bool]$cur
            Type   = if ($cur) { $cur.Type } else { $null }
            Value  = if ($cur) { $cur.Value } else { $null }
        }
    }
    @($data) | ConvertTo-Json -Depth 4 | Set-Content -Path $file -Encoding UTF8
}

function Restore-RegSnapshot {
    param([Parameter(Mandatory)][string]$Name)
    $file = Join-Path $script:LWUserDir "snapshot-$Name.json"
    if (-not (Test-Path $file)) { return $false }
    foreach ($e in @(Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        if ($e.Exists) {
            $v = if ($e.Type -eq 'Binary') { [Convert]::FromBase64String($e.Value) }
                 elseif ($e.Type -eq 'MultiString') { [string[]]$e.Value }
                 else { $e.Value }
            Set-RegValue -Path $e.Path -Name $e.Name -Value $v -Type $e.Type
        } elseif (Test-Path -LiteralPath $e.Path) {
            Remove-ItemProperty -LiteralPath $e.Path -Name $e.Name -ErrorAction SilentlyContinue
        }
    }
    return $true
}

# ------------------------------------------------------------------ 상태 파일
function Get-LWState {
    <# 사용자별 상태 (%LOCALAPPDATA%\LiteWin\state.json) #>
    $file = Join-Path $script:LWUserDir 'state.json'
    if (Test-Path $file) {
        try { return (Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { }
    }
    return [pscustomobject]@{ Mode = 'Lite'; UiOptions = @(); FirstRunDone = $false }
}

function Set-LWState {
    param([Parameter(Mandatory)]$State)
    New-Item -ItemType Directory -Path $script:LWUserDir -Force | Out-Null
    $State | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:LWUserDir 'state.json') -Encoding UTF8
}

function Get-LWProfile {
    <# 빌드 때 저장한 프로필 (없으면 기본값) #>
    $file = Join-Path $script:LWRoot 'profile.json'
    if (Test-Path $file) { try { return (Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { } }
    return [pscustomobject]@{ Name = 'Standard'; Defaults = [pscustomobject]@{ Mode = 'MacInput'; Apps = @() } }
}

# ------------------------------------------------------------------ winget
function Get-WingetPath {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    # SYSTEM 계정이나 첫 로그인 직후엔 PATH 에 없을 수 있음 → WindowsApps 에서 직접 찾기
    $found = Get-ChildItem "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) { return $found.FullName }
    return $null
}

function Wait-Winget {
    param([int]$TimeoutSeconds = 180)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        $w = Get-WingetPath
        if ($w) { return $w }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)
    return $null
}

function Test-Internet {
    try {
        $r = Invoke-WebRequest -UseBasicParsing -Uri 'https://www.msftconnecttest.com/connecttest.txt' -TimeoutSec 8
        return ($r.Content -like 'Microsoft Connect Test*')
    } catch { return $false }
}

function Invoke-Winget {
    <#
        winget 설치. 성공/이미 설치됨이면 $true.
        Source: winget(기본) 또는 msstore(Microsoft Store 앱/코덱)
    #>
    param(
        [Parameter(Mandatory)][string]$Id,
        [ValidateSet('winget', 'msstore')][string]$Source = 'winget',
        [ValidateSet('machine', 'user', '')][string]$Scope = '',
        [string[]]$ExtraArgs = @()
    )
    $winget = Wait-Winget -TimeoutSeconds 60
    if (-not $winget) { Write-LWLog 'winget 을 찾을 수 없습니다 (App Installer 미설치/등록 전)' ERROR; return $false }
    $wargs = @('install', '--id', $Id, '--exact', '--source', $Source, '--silent',
              '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity')
    if ($Scope) { $wargs += @('--scope', $Scope) }
    $wargs += $ExtraArgs
    & $winget @wargs | Out-Host
    $code = $LASTEXITCODE
    # 0 = 성공, -1978335189 (0x8A15002B) = 이미 설치됨/업데이트 없음, -1978335135 (0x8A150061) = 이미 설치됨
    $ok = $code -in @(0, -1978335189, -1978335135)
    if (-not $ok) { Write-LWLog "winget 실패: $Id ($Source) 코드 $code" WARN }
    return $ok
}
