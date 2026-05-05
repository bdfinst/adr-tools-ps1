function Get-AdrLinks {
    param([Parameter(Mandatory)][string]$Path)

    $lines = Get-Content -Path $Path
    $bounds = Get-AdrStatusBounds -Lines $lines -Path $Path
    if ($bounds.StartIndex -gt $bounds.EndIndex) { return @() }

    $results = @()
    $statusLines = $lines[$bounds.StartIndex..$bounds.EndIndex]
    foreach ($line in $statusLines) {
        # Match: LINK_TYPE [Title](NNNN-file.md)
        if ($line -match '^(.+?)\s+\[.*?\]\((\d{4})-.*?\.md\)') {
            $linkType = $Matches[1].Trim()
            $number   = [int]$Matches[2]
            # Skip reverse links (those ending in " by", case-insensitive)
            if ($linkType -match '\sby$') { continue }
            $results += [pscustomobject]@{ Number = $number; LinkType = $linkType }
        }
    }
    return $results
}
