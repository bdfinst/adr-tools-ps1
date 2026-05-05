function New-AdrSlug {
    param([Parameter(Mandatory)][string]$Title)
    $Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-' -replace '^-+|-+$', ''
}
