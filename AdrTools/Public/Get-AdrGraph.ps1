function Get-AdrGraph {
    param(
        [string]$Prefix    = '',
        [string]$Extension = '.html'
    )

    $adrs = Get-AdrList
    $lines = @('digraph {')

    # Emit nodes
    $nodeIds = @{}
    for ($i = 0; $i -lt $adrs.Count; $i++) {
        $path  = $adrs[$i]
        $title = Get-AdrTitle -Path $path
        $base  = [System.IO.Path]::GetFileNameWithoutExtension($path)
        $nodeId = "n$($i+1)"
        $nodeIds[$path] = $nodeId
        $url = "$Prefix$base$Extension"
        $lines += "  $nodeId [label=""$title"" shape=plaintext URL=""$url""]"
    }

    # Sequential (dotted) edges between consecutive ADRs
    for ($i = 0; $i -lt ($adrs.Count - 1); $i++) {
        $from = $nodeIds[$adrs[$i]]
        $to   = $nodeIds[$adrs[$i+1]]
        $lines += "  $from -> $to [style=""dotted"" weight=1]"
    }

    # Explicit link edges (forward links only; reverse links skipped by Get-AdrLinks)
    foreach ($adrPath in $adrs) {
        $fromId = $nodeIds[$adrPath]
        $links  = Get-AdrLinks -Path $adrPath
        foreach ($link in $links) {
            # Find the target ADR file by number
            $targetPath = $adrs | Where-Object {
                [int]([System.IO.Path]::GetFileName($_).Substring(0,4)) -eq $link.Number
            } | Select-Object -First 1
            if ($targetPath -and $nodeIds.ContainsKey($targetPath)) {
                $toId = $nodeIds[$targetPath]
                $lines += "  $fromId -> $toId [label=""$($link.LinkType)""]"
            }
        }
    }

    $lines += '}'
    $lines -join "`n"
}
