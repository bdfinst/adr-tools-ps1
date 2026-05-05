BeforeAll {
    $repoRoot  = Split-Path $PSScriptRoot -Parent
    $templates = Join-Path $repoRoot 'AdrTools' 'templates'
    $private   = Join-Path $repoRoot 'AdrTools' 'Private'
    . (Join-Path $private 'Write-AdrFile.ps1')
    $script:templates = $templates
    $script:repoRoot  = $repoRoot
}

Describe 'Templates' {
    It 'template.md exists' {
        Join-Path $script:templates 'template.md' | Should -Exist
    }

    It 'template.md contains required tokens' {
        $content = Get-Content (Join-Path $script:templates 'template.md') -Raw
        $content | Should -Match 'NUMBER'
        $content | Should -Match 'TITLE'
        $content | Should -Match 'DATE'
        $content | Should -Match 'STATUS'
    }

    It 'init.md exists' {
        Join-Path $script:templates 'init.md' | Should -Exist
    }

    It 'init.md contains DATE token' {
        $content = Get-Content (Join-Path $script:templates 'init.md') -Raw
        $content | Should -Match 'DATE'
    }

    It 'Token substitution matches golden-adr.md byte-for-byte' {
        # To regenerate golden-adr.md: delete it, set ADR_DATE=2024-01-15, run
        # New-Adr -Title 'Use Postgresql' against a fresh dir, copy the output here.
        $template = Get-Content (Join-Path $script:templates 'template.md') -Raw
        # Use case-sensitive -creplace so 'DATE' does not match 'Date:' in the template
        $result   = $template `
            -creplace 'NUMBER', '1' `
            -creplace 'TITLE',  'Use Postgresql' `
            -creplace 'DATE',   '2024-01-15' `
            -creplace 'STATUS', 'Accepted'

        $goldenPath = Join-Path $script:repoRoot 'Tests' 'Fixtures' 'golden-adr.md'
        $golden     = Get-Content $goldenPath -Raw

        # Normalise both to LF for comparison (git may have converted checkout)
        $resultNorm = $result  -replace "`r`n", "`n" -replace "`r", "`n"
        $goldenNorm = $golden  -replace "`r`n", "`n" -replace "`r", "`n"

        $resultNorm | Should -Be $goldenNorm
    }
}
