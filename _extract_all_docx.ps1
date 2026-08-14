Add-Type -AssemblyName System.IO.Compression.FileSystem
$i = 0
Get-ChildItem -LiteralPath 'C:\my-wiki\raw' -Filter *.docx | Sort-Object Name | ForEach-Object {
    $f = $_.FullName
    $name = $_.Name
    $zip = [System.IO.Compression.ZipFile]::OpenRead($f)
    $entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
    $reader = New-Object System.IO.StreamReader($entry.Open())
    $xml = $reader.ReadToEnd()
    $reader.Close(); $zip.Dispose()
    $xml = $xml -replace '</w:tc>',' | ' -replace '</w:tr>',"`n" -replace '</w:p>',"`n" -replace '<w:tab/>',"`t" -replace '<w:br/>',"`n"
    $text = [regex]::Replace($xml,'<[^>]+>','')
    $out = "C:\my-wiki\_docx_$i.txt"
    ("SOURCE: " + $name + "`n`n" + $text) | Out-File -FilePath $out -Encoding utf8
    Write-Output "written: $out chars=$($text.Length)"
    $i++
}