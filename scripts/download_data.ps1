# Downloads the MovieLens small dataset into ./data (ratings.csv + movies.csv)
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root "data"
$name = "ml-latest-small"
$zip  = Join-Path $env:TEMP "$name.zip"
$tmp  = Join-Path $env:TEMP "$name-extract"

Invoke-WebRequest "https://files.grouplens.org/datasets/movielens/$name.zip" -OutFile $zip
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive $zip -DestinationPath $tmp -Force
$src = Join-Path $tmp $name
Copy-Item (Join-Path $src "ratings.csv") $data -Force
Copy-Item (Join-Path $src "movies.csv")  $data -Force
Write-Host "Done:" (Get-ChildItem $data | ForEach-Object { "$($_.Name) ($([math]::Round($_.Length/1MB,1)) MB)" })
