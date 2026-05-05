function Initialize-AdrDirectory {
    param([string]$Directory = 'doc/adr')

    $adrDir   = $Directory
    $adrDirFull = Join-Path (Get-Location).Path $adrDir

    # Create the ADR directory if it doesn't exist
    if (-not (Test-Path $adrDirFull)) {
        New-Item -ItemType Directory -Path $adrDirFull -Force | Out-Null
    }

    # Write .adr-dir
    $adrDirFile = Join-Path (Get-Location).Path '.adr-dir'
    [System.IO.File]::WriteAllText($adrDirFile, $adrDir,
        (New-Object System.Text.UTF8Encoding($false)))

    # Create ADR #1 if it doesn't already exist
    $adr1Path = Join-Path $adrDirFull '0001-record-architecture-decisions.md'
    if (-not (Test-Path $adr1Path)) {
        $templatePath = Resolve-AdrTemplate -AdrDir $adrDirFull -TemplateType 'init'
        $date = if ($env:ADR_DATE) { $env:ADR_DATE } else { (Get-Date).ToString('yyyy-MM-dd') }
        $content = (Get-Content $templatePath -Raw) -creplace 'DATE', $date
        Write-AdrFile -Path $adr1Path -Content $content
    }
}
