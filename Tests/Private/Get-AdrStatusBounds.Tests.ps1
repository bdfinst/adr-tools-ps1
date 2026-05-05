BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'AdrTools' 'Private' 'Get-AdrStatusBounds.ps1')
}

Describe 'Get-AdrStatusBounds' {
    It 'Returns correct bounds for a standard ADR layout' {
        # Line indices: 0-based
        # 0: # 1. Title
        # 1: (blank)
        # 2: Date: 2024-01-01
        # 3: (blank)
        # 4: ## Status
        # 5: Accepted
        # 6: (blank)
        # 7: ## Context
        # 8: Some context.
        $lines = @(
            '# 1. Title',
            '',
            'Date: 2024-01-01',
            '',
            '## Status',
            'Accepted',
            '',
            '## Context',
            'Some context.'
        )
        $result = Get-AdrStatusBounds -Lines $lines -Path 'fake.md'
        $result.StartIndex | Should -Be 5
        $result.EndIndex   | Should -Be 6
    }

    It 'Status is last section (EOF): EndIndex = Lines.Count - 1' {
        $lines = @(
            '# 1. Title',
            '',
            'Date: 2024-01-01',
            '',
            '## Status',
            'Accepted',
            '',
            'Superceded by [Other](0002-other.md)'
        )
        $result = Get-AdrStatusBounds -Lines $lines -Path 'fake.md'
        $result.StartIndex | Should -Be 5
        $result.EndIndex   | Should -Be 7   # Lines.Count - 1
    }

    It 'Empty Status section: StartIndex > EndIndex' {
        $lines = @(
            '# 1. Title',
            '',
            '## Status',
            '## Context',
            'Context text.'
        )
        $result = Get-AdrStatusBounds -Lines $lines -Path 'fake.md'
        $result.StartIndex | Should -BeGreaterThan $result.EndIndex
    }

    It 'Throws when no ## Status heading is found' {
        $lines = @('# 1. Title', '', 'Date: 2024-01-01', '', '## Context', 'text')
        { Get-AdrStatusBounds -Lines $lines -Path 'myfile.md' } |
            Should -Throw -ExpectedMessage "*No '## Status' section found*"
    }

    It 'Matches ## Status with trailing whitespace' {
        $lines = @('## Status  ', 'Accepted', '## Context')
        $result = Get-AdrStatusBounds -Lines $lines -Path 'fake.md'
        $result.StartIndex | Should -Be 1
    }

    It 'Blank lines inside Status section are included in the range' {
        $lines = @(
            '## Status',
            '',
            'Accepted',
            '',
            '## Context'
        )
        $result = Get-AdrStatusBounds -Lines $lines -Path 'fake.md'
        $result.StartIndex | Should -Be 1
        $result.EndIndex   | Should -Be 3
    }
}
