function Resolve-AdrFile {
    param(
        [Parameter(Mandatory)][string]$Ref,
        [Parameter(Mandatory)][string]$AdrDir
    )

    # Normalise reference: strip leading zeros to get a plain integer string,
    # then match against 4-digit prefix or partial filename
    $numericRef = $null
    if ($Ref -match '^\d+$') {
        $numericRef = [int]$Ref
    }

    $matches = Get-ChildItem -Path $AdrDir -Filter '*.md' |
        Where-Object { $_.Name -match '^\d{4}-' } |
        Sort-Object Name |
        Where-Object {
            if ($null -ne $numericRef) {
                [int]($_.Name.Substring(0, 4)) -eq $numericRef
            } else {
                $_.Name -like "*$Ref*"
            }
        }

    if (-not $matches) {
        throw "ADR $Ref not found."
    }

    return @($matches)[0].FullName
}
