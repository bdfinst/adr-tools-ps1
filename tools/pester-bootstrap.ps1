# Installs Pester 5.x into tools/Pester/ if not already present.
# Source this script before invoking Pester in CI or local runs.
param(
    [string]$PesterVersion = '5.7.1'
)

$toolsDir = $PSScriptRoot
$pesterDir = Join-Path $toolsDir 'Pester'

$versionedDir = Join-Path $pesterDir $PesterVersion
if (-not (Test-Path (Join-Path $versionedDir 'Pester.psd1'))) {
    Write-Host "Installing Pester $PesterVersion to $pesterDir ..."
    Save-Module -Name Pester -RequiredVersion $PesterVersion -Path $toolsDir -Force
}

# Add tools/ to module path so Pester is discoverable (Save-Module uses tools/Pester/<version>/)
if ($env:PSModulePath -notlike "*$toolsDir*") {
    $env:PSModulePath = $toolsDir + [System.IO.Path]::PathSeparator + $env:PSModulePath
}

Import-Module (Join-Path $versionedDir 'Pester.psd1') -Force
Write-Host "Pester $(( Get-Module Pester ).Version) loaded."
