# Downloads MovieLens into ./data (ratings.csv + movies.csv)
#   .\scripts\download_data.ps1            small set, ~100k ratings (default, quick)
#   .\scripts\download_data.ps1 -Big       25M ratings (~650 MB), shows real HDFS block splitting
param([switch]$Big)

$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root "data"
$name = if ($Big) { "ml-25m" } else { "ml-latest-small" }
$zip  = Join-Path $env:TEMP "$name.zip"
$tmp  = Join-Path $env:TEMP "$name-extract"

Invoke-WebRequest "https://files.grouplens.org/datasets/movielens/$name.zip" -OutFile $zip
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive $zip -DestinationPath $tmp -Force
$src = Join-Path $tmp $name
Copy-Item (Join-Path $src "ratings.csv") $data -Force
Copy-Item (Join-Path $src "movies.csv")  $data -Force
Write-Host "Done:" (Get-ChildItem $data | ForEach-Object { "$($_.Name) ($([math]::Round($_.Length/1MB,1)) MB)" })
