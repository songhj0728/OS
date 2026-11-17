<#
    설치 이미지에 들어 있는 프로그램(payload\payloads.json)을 무인 설치한다.
    설치 마지막 단계(SetupComplete, SYSTEM 계정)에서 호출되고, CI 도 같은 함수로 검사한다.
    .OUTPUTS 기록할 문장들
#>
function Install-LWPayloads {
    param([Parameter(Mandatory)][string]$PayloadDir, [int]$TimeoutMinutes = 10)
    $json = Join-Path $PayloadDir 'payloads.json'
    if (-not (Test-Path $json)) { "payloads.json 없음 — 건너뜀"; return }
    foreach ($pl in @(Get-Content $json -Raw -Encoding UTF8 | ConvertFrom-Json)) {
        if (-not $pl -or -not $pl.File) { continue }
        $file = Join-Path $PayloadDir $pl.File
        if (-not (Test-Path $file)) { "없음: $($pl.File)"; continue }
        try {
            if ($file -like '*.zip') {
                # 포터블 프로그램: Program Files 아래에 풀고, zip 안에 폴더가 하나 더 있으면 끌어올린다
                $target = Join-Path $env:ProgramFiles $pl.PortableDir
                Expand-Archive -Path $file -DestinationPath $target -Force
                Resolve-LWPortableFolder -Target $target -ExeName "$($pl.PortableDir).exe"
                "설치(포터블): $($pl.Name) → $target"
                Remove-Item $file -Force -ErrorAction SilentlyContinue
                continue
            }
            if ($file -like '*.msi') { $proc = Start-Process msiexec.exe -ArgumentList "/i `"$file`" $($pl.Args)" -PassThru }
            elseif ($pl.Args)       { $proc = Start-Process $file -ArgumentList $pl.Args -PassThru }
            else                     { $proc = Start-Process $file -PassThru }
            # 무인 설치가 창을 띄우고 멈추면(SYSTEM 이라 보이지 않음) 설치 전체가 멈추므로 시간 제한을 둔다
            if (-not $proc.WaitForExit($TimeoutMinutes * 60000)) {
                $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                "설치 시간 초과($TimeoutMinutes 분): $($pl.Name) — 무인 설치 옵션($($pl.Args))이 맞지 않을 수 있음"
            } else { "설치: $($pl.Name) 종료 코드 $($proc.ExitCode) ($($pl.Args))" }
            if (-not $pl.Keep) { Remove-Item $file -Force -ErrorAction SilentlyContinue }   # EP 는 재설치용으로 보관
        } catch { "설치 실패: $($pl.Name) — $_" }
        if ($pl.PortableDir) { Resolve-LWPerUserInstall -Name $pl.PortableDir }
    }
}

function Resolve-LWPortableFolder([string]$Target, [string]$ExeName) {
    if (Test-Path (Join-Path $Target $ExeName)) { return }
    $exe = Get-ChildItem $Target -Recurse -File -Filter $ExeName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($exe) {
        Get-ChildItem $exe.DirectoryName -Force | Move-Item -Destination $Target -Force -ErrorAction SilentlyContinue
    }
}

function Resolve-LWPerUserInstall([string]$Name) {
    <#
        사용자별 설치 프로그램을 SYSTEM 으로 설치하면 SYSTEM 계정 폴더에 들어가 아무도 못 쓴다.
        그런 경우 Program Files 로 옮긴다 (RetroBar 등).
    #>
    $pf = Join-Path $env:ProgramFiles $Name
    if (Test-Path (Join-Path $pf "$Name.exe")) { return }
    foreach ($base in "$env:WINDIR\System32\config\systemprofile\AppData\Local\Programs", "$env:LOCALAPPDATA\Programs", "${env:ProgramFiles(x86)}") {
        $src = Join-Path $base $Name
        if (Test-Path (Join-Path $src "$Name.exe")) {
            New-Item -ItemType Directory -Path $pf -Force | Out-Null
            Copy-Item (Join-Path $src '*') $pf -Recurse -Force
            "옮김: $src → $pf (모든 사용자가 쓰도록)"
            return
        }
    }
    "확인 필요: $Name.exe 를 찾지 못함"
}
