<#
    Windows 설치 화면 배경 이미지 만들기 (Build-LiteWin.ps1 과 CI 가 같이 쓴다)
#>
Add-Type -AssemblyName System.Drawing

function ConvertFrom-HexColor([string]$Hex) {
    if ($Hex -notmatch '^#?([0-9a-fA-F]{6})$') { throw "색상 형식이 아닙니다: $Hex (예: #2B2F38)" }
    $rgb = [Convert]::ToInt32($Matches[1], 16)
    [System.Drawing.Color]::FromArgb(($rgb -shr 16) -band 255, ($rgb -shr 8) -band 255, $rgb -band 255)
}

function New-SolidImageLike {
    <#
        .SYNOPSIS 원본 배경 파일과 같은 크기·형식(bmp/png/jpg)으로 단색 이미지를 만든다
        .PARAMETER Template  원본 배경 파일 (읽을 수 없으면 1920x1080)
    #>
    param([Parameter(Mandatory)][string]$Template, [Parameter(Mandatory)][System.Drawing.Color]$Color, [Parameter(Mandatory)][string]$OutFile)
    $w = 1920; $h = 1080
    try {
        # 파일을 잠그지 않도록 스트림으로 읽고 바로 닫는다 (마운트 해제 방해 방지)
        $fs = [IO.File]::OpenRead($Template)
        try { $im = [System.Drawing.Image]::FromStream($fs); $w = $im.Width; $h = $im.Height; $im.Dispose() } finally { $fs.Dispose() }
    } catch { }
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp); $g.Clear($Color); $g.Dispose()
        $fmt = switch ([IO.Path]::GetExtension($Template).ToLower()) {
            '.png' { [System.Drawing.Imaging.ImageFormat]::Png }
            '.jpg' { [System.Drawing.Imaging.ImageFormat]::Jpeg }
            default { [System.Drawing.Imaging.ImageFormat]::Bmp }
        }
        $bmp.Save($OutFile, $fmt)
    } finally { $bmp.Dispose() }
    return [pscustomobject]@{ Width = $w; Height = $h; File = $OutFile }
}
