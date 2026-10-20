# Downloads MovieLens 20M (20 million ratings) and puts ratings.csv + movies.csv into ./data
# (only these two files are taken out of the zip, the rest is not needed)
$root = Split-Path -Parent $PSScriptRoot
$data = Join-Path $root "data"
$zip  = Join-Path $env:TEMP "ml-20m.zip"

if (-not (Test-Path $zip)) {
    Invoke-WebRequest "https://files.grouplens.org/datasets/movielens/ml-20m.zip" -OutFile $zip
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
try {
    foreach ($name in "ratings.csv", "movies.csv") {
        $entry = $archive.Entries | Where-Object { $_.FullName -eq "ml-20m/$name" }
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $data $name), $true)
    }
} finally { $archive.Dispose() }

Get-ChildItem $data -Filter *.csv | ForEach-Object { "{0}  {1:N0} MB" -f $_.Name, ($_.Length / 1MB) }
