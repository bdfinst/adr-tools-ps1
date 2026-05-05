function Get-AdrHelp {
    # MAINTENANCE: update $HelpText entries when command parameters change
    param([string]$Command = '')

    $HelpText = @{
        'init'               = "adr init [DIRECTORY]`n  Initialize the ADR directory (default: doc/adr)."
        'new'                = "adr new [-s N]... [-l TARGET:LINK:REVERSE-LINK]... TITLE...`n  Create a new ADR.`n  -s N  Supersede ADR number N (repeatable)`n  -l TARGET:LINK:REVERSE-LINK  Add a directional link (repeatable)`n  Example: adr new My Decision -s 2 -l 3:Amends:'Amended by'"
        'list'               = "adr list`n  List all ADR files."
        'link'               = "adr link SOURCE LINK TARGET REVERSE-LINK`n  Add bidirectional links between two ADRs."
        'generate'           = "adr generate toc [-i INTRO] [-o OUTRO] [-p PREFIX]`nadr generate graph [-p PREFIX] [-e EXT]`n  Generate documentation from ADRs."
        'upgrade-repository' = "adr upgrade-repository`n  Convert DD/MM/YYYY dates to ISO 8601 format."
        'help'               = "adr help [COMMAND]`n  Show help for all or a specific command."
    }

    if ([string]::IsNullOrEmpty($Command)) {
        $out = "adr - Architecture Decision Records tool`n`nAvailable commands:`n"
        $out += ($HelpText.Keys | Sort-Object | ForEach-Object { "  $_" }) -join "`n"
        return $out
    }

    if (-not $HelpText.ContainsKey($Command)) {
        throw "Unknown command: $Command"
    }

    return $HelpText[$Command]
}
