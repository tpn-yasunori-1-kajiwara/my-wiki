param($f, $out)
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead($f)
$entry = $zip.Entries | Where-Object { $_.FullName -eq 'word/document.xml' }
$reader = New-Object System.IO.StreamReader($entry.Open())
$xml = $reader.ReadToEnd()
$reader.Close(); $zip.Dispose()
$xml = $xml -replace '</w:tc>',' | ' -replace '</w:tr>',"`n" -replace '</w:p>',"`n" -replace '<w:tab/>',"`t" -replace '<w:br/>',"`n"
$text = [regex]::Replace($xml,'<[^>]+>','')
$text | Out-File -FilePath $out -Encoding utf8
Write-Output "written: $out chars=$($text.Length)"
