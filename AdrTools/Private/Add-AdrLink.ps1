function Add-AdrLink {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$LinkText
    )

    $lines  = [System.Collections.Generic.List[string]](Get-Content -Path $Path)
    $bounds = Get-AdrStatusBounds -Lines $lines.ToArray() -Path $Path

    # Insert the link line just after the last line of the Status section
    $insertAt = $bounds.EndIndex + 1
    $lines.Insert($insertAt, $LinkText)

    Write-AdrFile -Path $Path -Content ($lines -join "`n")
}
