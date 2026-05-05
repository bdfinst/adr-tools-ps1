function Get-NextAdrNumber {
    param([Parameter(Mandatory)][string]$AdrDir)

    if (-not (Test-Path $AdrDir)) {
        throw "ADR directory '$AdrDir' does not exist."
    }
    if (-not (Test-Path $AdrDir -PathType Container)) {
        throw "Path '$AdrDir' is not a directory."
    }

    $max = Get-ChildItem -Path $AdrDir -Filter '*.md' |
        Where-Object { $_.Name -match '^\d{4}-' } |
        ForEach-Object { [int]($_.Name.Substring(0, 4)) } |
        Measure-Object -Maximum |
        Select-Object -ExpandProperty Maximum

    if ($null -eq $max -or $max -lt 1) { return 1 }
    return $max + 1
}
