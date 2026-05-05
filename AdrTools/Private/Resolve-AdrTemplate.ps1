function Resolve-AdrTemplate {
    param(
        [Parameter(Mandatory)][string]$AdrDir,
        [string]$TemplateType = 'template'   # 'template' or 'init'
    )

    # 1. ADR_TEMPLATE env var overrides everything (only for 'template' type)
    if ($TemplateType -eq 'template' -and -not [string]::IsNullOrEmpty($env:ADR_TEMPLATE)) {
        if (-not (Test-Path $env:ADR_TEMPLATE)) {
            throw "Template file not found: $($env:ADR_TEMPLATE)"
        }
        return $env:ADR_TEMPLATE
    }

    # 2. <adr-dir>/templates/<type>.md
    $adrDirTemplate = Join-Path $AdrDir 'templates' "$TemplateType.md"
    if (Test-Path $adrDirTemplate) {
        return $adrDirTemplate
    }

    # 3. Built-in template
    return Join-Path $PSScriptRoot '..' 'templates' "$TemplateType.md"
}
