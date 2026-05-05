BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')
    . (Join-Path $public 'Get-AdrList.ps1')
    . (Join-Path $public 'Get-AdrGraph.ps1')
}

Describe 'Get-AdrGraph' {
    BeforeAll {
        $dir = Join-Path $TestDrive 'graph-test'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        Initialize-AdrDirectory | Out-Null
        New-Adr -Title 'Use REST' | Out-Null
        # ADR 3 amends ADR 2
        New-Adr -Title 'Add GraphQL' -Link @('2:Amends:Amended by') | Out-Null
        Pop-Location
        $script:graphDir = $dir
        $script:dot = & { Push-Location $dir; $g = Get-AdrGraph; Pop-Location; $g }
    }

    It 'Output starts with digraph {' {
        $script:dot | Should -Match '^digraph \{'
    }

    It 'Output ends with }' {
        $script:dot.TrimEnd() | Should -Match '\}$'
    }

    It 'Each ADR has a node with plaintext shape' {
        $script:dot | Should -Match 'shape=plaintext'
    }

    It 'Sequential ADRs have a dotted edge' {
        $script:dot | Should -Match 'style="dotted"'
    }

    It 'Linked ADRs have a directed edge with label' {
        $script:dot | Should -Match 'label="Amends"'
    }

    It 'Reverse links are not emitted as separate edges' {
        $script:dot | Should -Not -Match 'label="Amended by"'
    }

    It 'Prefix and extension are applied to node URLs' {
        Push-Location $script:graphDir
        try {
            $dot = Get-AdrGraph -Prefix '/adr/' -Extension '.html'
            $dot | Should -Match 'URL="/adr/.*\.html"'
        } finally { Pop-Location }
    }

    It 'DOT output is valid when Graphviz is available' -Skip:(-not (Get-Command dot -ErrorAction SilentlyContinue)) {
        $tmpSvg = Join-Path $TestDrive 'graph.svg'
        Push-Location $script:graphDir
        try {
            $dot = Get-AdrGraph
            $dot | & dot -Tsvg -o $tmpSvg
            $LASTEXITCODE | Should -Be 0
        } finally { Pop-Location }
    }
}
