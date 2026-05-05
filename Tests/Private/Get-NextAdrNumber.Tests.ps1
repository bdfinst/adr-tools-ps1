BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'AdrTools' 'Private' 'Get-NextAdrNumber.ps1')
}

Describe 'Get-NextAdrNumber' {
    It 'Returns 1 for an empty directory' {
        $dir = Join-Path $TestDrive 'empty-adr'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Get-NextAdrNumber -AdrDir $dir | Should -Be 1
    }

    It 'Returns next after highest number (sequential)' {
        $dir = Join-Path $TestDrive 'seq-adr'
        New-Item -ItemType Directory -Path $dir | Out-Null
        '0001-foo.md', '0002-bar.md', '0003-baz.md' | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $dir $_) | Out-Null
        }
        Get-NextAdrNumber -AdrDir $dir | Should -Be 4
    }

    It 'Returns next after highest in sparse directory' {
        $dir = Join-Path $TestDrive 'sparse-adr'
        New-Item -ItemType Directory -Path $dir | Out-Null
        '0001-a.md', '0005-b.md' | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $dir $_) | Out-Null
        }
        Get-NextAdrNumber -AdrDir $dir | Should -Be 6
    }

    It 'Ignores non-ADR files' {
        $dir = Join-Path $TestDrive 'mixed-adr'
        New-Item -ItemType Directory -Path $dir | Out-Null
        'README.md', 'templates' | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $dir $_) | Out-Null
        }
        '0001-a.md' | ForEach-Object {
            New-Item -ItemType File -Path (Join-Path $dir $_) | Out-Null
        }
        Get-NextAdrNumber -AdrDir $dir | Should -Be 2
    }

    It 'Treats 0000-*.md as number 0 and returns 1' {
        $dir = Join-Path $TestDrive 'zero-adr'
        New-Item -ItemType Directory -Path $dir | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir '0000-init.md') | Out-Null
        Get-NextAdrNumber -AdrDir $dir | Should -Be 1
    }

    It 'Throws when directory does not exist' {
        { Get-NextAdrNumber -AdrDir (Join-Path $TestDrive 'nonexistent') } |
            Should -Throw -ExpectedMessage '*does not exist*'
    }

    It 'Throws when path is a file not a directory' {
        $file = Join-Path $TestDrive 'afile.txt'
        New-Item -ItemType File -Path $file | Out-Null
        { Get-NextAdrNumber -AdrDir $file } |
            Should -Throw
    }
}
