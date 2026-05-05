function Get-AdrDirectory {
    $current = (Get-Location).Path
    if ([string]::IsNullOrEmpty($current)) {
        throw "No ADR directory found. Run 'adr init' to create one."
    }
    $drive = [System.IO.Path]::GetPathRoot($current)

    # Walk up the directory tree looking for .adr-dir
    $dir = $current
    while (-not [string]::IsNullOrEmpty($dir)) {
        $candidate = Join-Path $dir '.adr-dir'
        if (Test-Path $candidate -PathType Leaf) {
            try {
                $relPath = (Get-Content $candidate -TotalCount 1).Trim()
                # Resolve relative to the directory containing .adr-dir so callers
                # always get an absolute path (needed for [System.IO.File] APIs)
                return [System.IO.Path]::GetFullPath((Join-Path $dir $relPath))
            } catch {
                throw "Cannot read '$candidate': $_"
            }
        }
        $parent = Split-Path $dir -Parent
        if ($parent -eq $dir -or $dir -eq $drive) { break }
        $dir = $parent
    }

    # Fallback: look for doc/adr under the starting directory
    $docAdr = Join-Path $current 'doc' 'adr'
    if (Test-Path $docAdr -PathType Container) {
        return [System.IO.Path]::GetFullPath($docAdr)
    }

    throw "No ADR directory found. Run 'adr init' to create one."
}
