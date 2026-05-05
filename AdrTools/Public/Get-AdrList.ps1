function Get-AdrList {
    $adrDir = Get-AdrDirectory
    Get-ChildItem -Path $adrDir -Filter '*.md' |
        Where-Object { $_.Name -match '^\d{4}-' } |
        Sort-Object Name |
        Select-Object -ExpandProperty FullName
}
