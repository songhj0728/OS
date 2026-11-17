<#
    Windows 기본 앱 연결 파일(OEMDefaultAssociations.xml) 병합.
    Windows 는 새 사용자를 만들 때 이 파일로 기본 앱을 정한다. 원본에는 웹/HTML/PDF/XML 등이 Edge(MSEdge*)로 적혀 있어서,
    Edge 를 지운 뒤에도 그 항목이 남으면 XML 같은 파일에서 Edge 가 다시 나타난다.
    → 원본을 읽어 Edge 항목을 브라우저로 바꾸고, LiteWin 항목을 합친 '전체' 파일을 DISM 으로 가져온다
      (DISM 가져오기는 파일 전체를 교체하므로, 일부만 넣으면 다른 기본값이 사라지기 때문에 반드시 병합).
#>

# 브라우저가 맡을 형식 (Edge 가 원래 맡던 것 포함)
$script:BrowserIdentifiers = @('http', 'https', '.htm', '.html', '.shtml', '.xht', '.xhtml', '.svg', '.pdf', '.xml', '.mht', '.mhtml', '.webp')

function Merge-DefaultAssociations {
    <#
    .PARAMETER Source   기존 OEMDefaultAssociations.xml (없으면 새로 만든다)
    .PARAMETER Output   병합 결과 파일
    .PARAMETER Entries  @{ '.mp4' = @('ProgId', '앱 이름'); ... }
    .PARAMETER Browser  @('ChromeHTML', 'Google Chrome') — MSEdge* 로 적힌 항목을 모두 이걸로 바꾼다
    #>
    param(
        [string]$Source,
        [Parameter(Mandatory)][string]$Output,
        [System.Collections.IDictionary]$Entries = @{},
        [string[]]$Browser
    )
    $doc = New-Object System.Xml.XmlDocument
    if ($Source -and (Test-Path $Source)) { $doc.Load($Source) }
    else { $doc.LoadXml('<?xml version="1.0" encoding="UTF-8"?><DefaultAssociations></DefaultAssociations>') }
    $rootNode = $doc.DocumentElement

    if ($Browser) {
        foreach ($n in @($rootNode.SelectNodes('Association'))) {
            if ($n.GetAttribute('ProgId') -match '^(MSEdge|AppX.*Edge)' -or $n.GetAttribute('ApplicationName') -match 'Edge') {
                $n.SetAttribute('ProgId', $Browser[0]); $n.SetAttribute('ApplicationName', $Browser[1])
            }
        }
        foreach ($id in $script:BrowserIdentifiers) { if (-not $Entries.Contains($id)) { $Entries[$id] = $Browser } }
    }

    foreach ($id in @($Entries.Keys)) {
        $node = $null
        foreach ($n in @($rootNode.SelectNodes('Association'))) {
            if ($n.GetAttribute('Identifier') -ieq $id) { $node = $n; break }
        }
        if (-not $node) { $node = $doc.CreateElement('Association'); [void]$rootNode.AppendChild($node); $node.SetAttribute('Identifier', $id) }
        $node.SetAttribute('ProgId', $Entries[$id][0])
        $node.SetAttribute('ApplicationName', $Entries[$id][1])
    }
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true; $settings.Encoding = New-Object System.Text.UTF8Encoding $false
    $w = [System.Xml.XmlWriter]::Create($Output, $settings)
    try { $doc.Save($w) } finally { $w.Close() }
}
