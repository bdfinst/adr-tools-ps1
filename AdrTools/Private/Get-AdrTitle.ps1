function Get-AdrTitle {
    param([Parameter(Mandatory)][string]$Path)

    $firstLine = (Get-Content -Path $Path -TotalCount 1)
    # Strip BOM (U+FEFF) that PS5.1 may surface from externally-authored files
    $firstLine = $firstLine.TrimStart([char]0xFEFF).TrimEnd()
    # Strip "# N. " heading prefix
    $firstLine -replace '^#\s+\d+\.\s*', ''
}
