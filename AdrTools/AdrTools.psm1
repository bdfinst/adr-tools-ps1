# Dot-source all private helpers, then all public functions
$privateDir = Join-Path $PSScriptRoot 'Private'
$publicDir  = Join-Path $PSScriptRoot 'Public'

foreach ($file in (Get-ChildItem -Path $privateDir -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
    . $file.FullName
}
foreach ($file in (Get-ChildItem -Path $publicDir -Filter '*.ps1' -ErrorAction SilentlyContinue)) {
    . $file.FullName
}
