param(
    [Parameter(Mandatory = $true)]
    [string]$DocxPath,
    [Parameter(Mandatory = $true)]
    [string]$PdfPath,
    [Parameter(Mandatory = $true)]
    [string]$StatusPath
)

$ErrorActionPreference = "Stop"
$word = $null
$doc = $null

try {
    $parent = Split-Path -Parent $PdfPath
    New-Item -ItemType Directory -Force -Path $parent | Out-Null

    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0
    $word.AutomationSecurity = 3

    $doc = $word.Documents.Open($DocxPath, $false, $false, $false)
    foreach ($toc in $doc.TablesOfContents) {
        $toc.Update()
    }
    $doc.Fields.Update() | Out-Null
    $doc.Repaginate()
    $doc.Save()
    $pages = $doc.ComputeStatistics(2)
    $doc.ExportAsFixedFormat($PdfPath, 17)

    "SUCCESS|$pages|$PdfPath" | Set-Content -LiteralPath $StatusPath -Encoding UTF8
}
catch {
    "ERROR|$($_.Exception.Message)" | Set-Content -LiteralPath $StatusPath -Encoding UTF8
    throw
}
finally {
    if ($doc -ne $null) {
        $doc.Close($false)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($doc) | Out-Null
    }
    if ($word -ne $null) {
        $word.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    }
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}
