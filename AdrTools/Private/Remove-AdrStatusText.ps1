function Remove-AdrStatusText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Text
    )

    $lines  = [System.Collections.Generic.List[string]](Get-Content -Path $Path)
    $bounds = Get-AdrStatusBounds -Lines $lines.ToArray() -Path $Path

    $found = $false
    for ($i = $bounds.StartIndex; $i -le $bounds.EndIndex; $i++) {
        if ($lines[$i].Trim() -eq $Text.Trim()) {
            $lines.RemoveAt($i)
            $found = $true
            break
        }
    }

    if ($found) {
        Write-AdrFile -Path $Path -Content ($lines -join "`n")
    }
}
