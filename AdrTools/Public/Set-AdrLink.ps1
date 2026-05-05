function Set-AdrLink {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$LinkText,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$ReverseLinkText
    )

    $adrDir = Get-AdrDirectory

    # Fail-fast: resolve both files before any modification
    $sourceFile = Resolve-AdrFile -Ref $Source -AdrDir $adrDir
    $targetFile = Resolve-AdrFile -Ref $Target -AdrDir $adrDir

    $sourceTitle = Get-AdrTitle -Path $sourceFile
    $targetTitle = Get-AdrTitle -Path $targetFile
    $sourceBase  = [System.IO.Path]::GetFileName($sourceFile)
    $targetBase  = [System.IO.Path]::GetFileName($targetFile)

    Add-AdrLink -Path $sourceFile -LinkText "$LinkText [$targetTitle]($targetBase)"
    Add-AdrLink -Path $targetFile -LinkText "$ReverseLinkText [$sourceTitle]($sourceBase)"
}
