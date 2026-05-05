BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'AdrTools' 'Public' 'Get-AdrHelp.ps1')
}

Describe 'Get-AdrHelp' {
    It 'Lists all command names when called with no argument' {
        $output = Get-AdrHelp
        $output | Should -Match 'init'
        $output | Should -Match 'new'
        $output | Should -Match 'list'
        $output | Should -Match 'link'
        $output | Should -Match 'generate'
        $output | Should -Match 'upgrade-repository'
    }

    It 'Shows -s and -l flags with format example for "new" command' {
        $output = Get-AdrHelp -Command 'new'
        $output | Should -Match '\-s'
        $output | Should -Match '\-l'
        $output | Should -Match 'TARGET:LINK:REVERSE-LINK'
    }

    It 'Throws for unknown command' {
        { Get-AdrHelp -Command 'unknowncmd' } |
            Should -Throw -ExpectedMessage '*Unknown command: unknowncmd*'
    }
}
