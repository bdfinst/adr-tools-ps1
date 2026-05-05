BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private = Join-Path $repoRoot 'AdrTools' 'Private'
    . (Join-Path $private 'Write-AdrFile.ps1')
    . (Join-Path $private 'Get-AdrStatusBounds.ps1')
    . (Join-Path $private 'Add-AdrLink.ps1')
    . (Join-Path $private 'Remove-AdrStatusText.ps1')

    function script:New-AdrWithStatus {
        param([string]$Path, [string]$StatusBody)
        $content = "# 1. Title`n`nDate: 2024-01-01`n`n## Status`n`n$StatusBody`n`n## Context`n`nContext text.`n"
        Write-AdrFile -Path $Path -Content $content
    }
}

Describe 'Add-AdrLink' {
    It 'Inserts link at the end of Status section' {
        $file = Join-Path $TestDrive 'add-link-basic.md'
        New-AdrWithStatus -Path $file -StatusBody 'Accepted'
        Add-AdrLink -Path $file -LinkText 'Amends [Use MySQL](0002-use-mysql.md)'
        $content = Get-Content $file -Raw
        $content | Should -Match 'Amends \[Use MySQL\]\(0002-use-mysql\.md\)'
        # The link should appear before the next ## heading
        $content | Should -Match 'Amends.*\n+## Context'
    }

    It 'Appends after existing Status content' {
        $file = Join-Path $TestDrive 'add-link-existing.md'
        New-AdrWithStatus -Path $file -StatusBody 'Accepted'
        Add-AdrLink -Path $file -LinkText 'Amends [A](0001-a.md)'
        Add-AdrLink -Path $file -LinkText 'Amends [B](0002-b.md)'
        $content = Get-Content $file -Raw
        $content | Should -Match 'Amends \[A\]'
        $content | Should -Match 'Amends \[B\]'
    }

    It 'Works when Status is the last section (no following ##)' {
        $content = "# 1. Title`n`nDate: 2024-01-01`n`n## Status`n`nAccepted`n"
        $file = Join-Path $TestDrive 'add-link-eof.md'
        Write-AdrFile -Path $file -Content $content
        Add-AdrLink -Path $file -LinkText 'Amends [X](0003-x.md)'
        $result = Get-Content $file -Raw
        $result | Should -Match 'Amends \[X\]'
    }

    It 'Written file has no BOM' {
        $file = Join-Path $TestDrive 'add-link-nobom.md'
        New-AdrWithStatus -Path $file -StatusBody 'Accepted'
        Add-AdrLink -Path $file -LinkText 'Amends [X](0002-x.md)'
        $bytes = [System.IO.File]::ReadAllBytes($file)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
    }

    It 'Written file has LF-only line endings' {
        $file = Join-Path $TestDrive 'add-link-lf.md'
        New-AdrWithStatus -Path $file -StatusBody 'Accepted'
        Add-AdrLink -Path $file -LinkText 'Amends [X](0002-x.md)'
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $bytes | Should -Not -Contain 0x0D
    }
}

Describe 'Remove-AdrStatusText' {
    It 'Removes an exact line from the Status section' {
        $file = Join-Path $TestDrive 'remove-accepted.md'
        New-AdrWithStatus -Path $file -StatusBody 'Accepted'
        Remove-AdrStatusText -Path $file -Text 'Accepted'
        $content = Get-Content $file -Raw
        $content | Should -Not -Match '^Accepted$'
    }

    It 'Leaves file unchanged when text is not present' {
        $file = Join-Path $TestDrive 'remove-absent.md'
        New-AdrWithStatus -Path $file -StatusBody 'Accepted'
        $before = [System.IO.File]::ReadAllBytes($file)
        Remove-AdrStatusText -Path $file -Text 'NonExistentText'
        $after = [System.IO.File]::ReadAllBytes($file)
        ($before -join ',') | Should -Be ($after -join ',')
    }
}
