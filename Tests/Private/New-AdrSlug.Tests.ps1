BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'AdrTools' 'Private' 'New-AdrSlug.ps1')
}

Describe 'New-AdrSlug' {
    It 'Converts plain title to lowercase hyphenated slug' {
        New-AdrSlug 'Use PostgreSQL for the database' |
            Should -Be 'use-postgresql-for-the-database'
    }

    It 'Replaces special characters with hyphens' {
        New-AdrSlug 'Use React.js & TypeScript' |
            Should -Be 'use-react-js-typescript'
    }

    It 'Collapses consecutive hyphens' {
        New-AdrSlug 'Use---Multiple---Dashes' |
            Should -Be 'use-multiple-dashes'
    }

    It 'Strips leading and trailing hyphens' {
        New-AdrSlug '  Leading spaces  ' |
            Should -Not -Match '^-|-$'
    }

    It 'Lowercases all characters' {
        New-AdrSlug 'Already-Slugged' | Should -Be 'already-slugged'
    }

    It 'Handles non-ASCII as non-alphanumeric (replaced with hyphen)' {
        $result = New-AdrSlug 'Ångström'
        $result | Should -Match '^[a-z0-9-]+$'
        $result | Should -Not -Match '^-|-$'
    }
}
