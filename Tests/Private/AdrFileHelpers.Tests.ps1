BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private = Join-Path $repoRoot 'AdrTools' 'Private'
    . (Join-Path $private 'Write-AdrFile.ps1')
    . (Join-Path $private 'Get-AdrStatusBounds.ps1')
    . (Join-Path $private 'Resolve-AdrFile.ps1')
    . (Join-Path $private 'Get-AdrTitle.ps1')
    . (Join-Path $private 'Get-AdrStatus.ps1')
    . (Join-Path $private 'Get-AdrLinks.ps1')

    # Helper available in all child blocks via Pester BeforeAll scope
    function script:New-TestAdr {
        param([string]$Dir, [string]$Name, [string]$Title, [string]$StatusBody = 'Accepted')
        $content = "# $Title`n`nDate: 2024-01-01`n`n## Status`n`n$StatusBody`n`n## Context`n`nSome context.`n`n## Decision`n`nA decision.`n`n## Consequences`n`nSome consequences.`n"
        Write-AdrFile -Path (Join-Path $Dir $Name) -Content $content
    }
}

Describe 'Resolve-AdrFile' {
    BeforeAll {
        $dir = Join-Path $TestDrive 'resolve-adrs'
        New-Item -ItemType Directory -Path $dir | Out-Null
        New-TestAdr -Dir $dir -Name '0001-record-decisions.md' -Title '1. Record Decisions'
        New-TestAdr -Dir $dir -Name '0002-use-mysql.md'        -Title '2. Use MySQL'
        New-TestAdr -Dir $dir -Name '0005-use-postgres.md'     -Title '5. Use Postgres'
        $script:resolveDir = $dir
    }

    It 'Resolves by plain number "2"' {
        $result = Resolve-AdrFile -Ref '2' -AdrDir $script:resolveDir
        $result | Should -BeLike '*0002-use-mysql.md'
    }

    It 'Resolves by zero-padded number "0002"' {
        $result = Resolve-AdrFile -Ref '0002' -AdrDir $script:resolveDir
        $result | Should -BeLike '*0002-use-mysql.md'
    }

    It 'Resolves by partial name "postgres"' {
        $result = Resolve-AdrFile -Ref 'postgres' -AdrDir $script:resolveDir
        $result | Should -BeLike '*0005-use-postgres.md'
    }

    It 'Returns the lowest-numbered match when multiple files match' {
        $result = Resolve-AdrFile -Ref 'use' -AdrDir $script:resolveDir
        $result | Should -BeLike '*0002-use-mysql.md'
    }

    It 'Throws "ADR 99 not found." when no match exists' {
        { Resolve-AdrFile -Ref '99' -AdrDir $script:resolveDir } |
            Should -Throw -ExpectedMessage '*ADR 99 not found*'
    }
}

Describe 'Get-AdrTitle' {
    It 'Strips "# N. " prefix and returns the title' {
        $file = Join-Path $TestDrive 'title-test.md'
        New-TestAdr -Dir $TestDrive -Name 'title-test.md' -Title '4. Use PostgreSQL'
        Get-AdrTitle -Path $file | Should -Be 'Use PostgreSQL'
    }

    It 'Returns correct title when first line has no trailing CR' {
        $file = Join-Path $TestDrive 'crlf-test.md'
        Write-AdrFile -Path $file -Content "# 3. My Title`n`nDate: 2024-01-01"
        Get-AdrTitle -Path $file | Should -Be 'My Title'
    }

    It 'Handles BOM-prefixed file without including BOM in title' {
        $file = Join-Path $TestDrive 'bom-test.md'
        # Write a file with BOM manually
        $bom = [byte[]](0xEF, 0xBB, 0xBF)
        $content = [System.Text.Encoding]::UTF8.GetBytes("# 5. BOM Title`n`nDate: 2024-01-01")
        [System.IO.File]::WriteAllBytes($file, $bom + $content)
        Get-AdrTitle -Path $file | Should -Be 'BOM Title'
    }
}

Describe 'Get-AdrStatus' {
    It 'Returns status lines between ## Status and next ##' {
        $file = Join-Path $TestDrive 'status-test.md'
        New-TestAdr -Dir $TestDrive -Name 'status-test.md' -Title '1. T' -StatusBody 'Accepted'
        $status = Get-AdrStatus -Path $file
        $status | Should -Contain 'Accepted'
    }
}

Describe 'Get-AdrLinks' {
    It 'Parses a forward link from Status section' {
        $file = Join-Path $TestDrive 'links-fwd.md'
        New-TestAdr -Dir $TestDrive -Name 'links-fwd.md' -Title '1. T' `
            -StatusBody "Accepted`n`nAmends [Use MySQL](0002-use-mysql.md)"
        $links = Get-AdrLinks -Path $file
        $links.Count | Should -Be 1
        $links[0].Number   | Should -Be 2
        $links[0].LinkType | Should -Be 'Amends'
    }

    It 'Skips reverse links containing " by"' {
        $file = Join-Path $TestDrive 'links-rev.md'
        New-TestAdr -Dir $TestDrive -Name 'links-rev.md' -Title '1. T' `
            -StatusBody "Accepted`n`nAmended by [New](0003-new.md)`n`nAmends [Old](0001-old.md)"
        $links = Get-AdrLinks -Path $file
        $links.Count | Should -Be 1
        $links[0].LinkType | Should -Be 'Amends'
    }

    It 'Returns empty array when no links present' {
        $file = Join-Path $TestDrive 'links-none.md'
        New-TestAdr -Dir $TestDrive -Name 'links-none.md' -Title '1. T'
        $links = Get-AdrLinks -Path $file
        @($links).Count | Should -Be 0
    }
}
