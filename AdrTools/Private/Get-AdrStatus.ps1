function Get-AdrStatus {
    param([Parameter(Mandatory)][string]$Path)

    $lines = Get-Content -Path $Path
    $bounds = Get-AdrStatusBounds -Lines $lines -Path $Path
    if ($bounds.StartIndex -gt $bounds.EndIndex) { return @() }
    $lines[$bounds.StartIndex..$bounds.EndIndex] | Where-Object { $_.Trim() -ne '' }
}
