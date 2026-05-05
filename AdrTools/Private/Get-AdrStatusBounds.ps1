function Get-AdrStatusBounds {
    # Note: [string[]] with Mandatory rejects arrays containing empty strings in PS7.
    # Manual null/empty checks replace Mandatory here.
    param(
        [string[]]$Lines,
        [string]$Path
    )
    if ($null -eq $Lines) { throw "Lines must not be null." }

    # Find the ## Status heading (strip BOM and trailing whitespace)
    $statusIdx = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].TrimStart([char]0xFEFF).TrimEnd()
        if ($line -eq '## Status') {
            $statusIdx = $i
            break
        }
    }

    if ($statusIdx -lt 0) {
        throw "No '## Status' section found in file: $Path"
    }

    # StartIndex = first line after the ## Status heading
    $startIndex = $statusIdx + 1

    # EndIndex = last line before the next ## heading, or last line of file
    $endIndex = $Lines.Count - 1
    for ($i = $startIndex; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i].TrimStart([char]0xFEFF)
        if ($line -match '^## ') {
            $endIndex = $i - 1
            break
        }
    }

    return @{ StartIndex = $startIndex; EndIndex = $endIndex }
}
