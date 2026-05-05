BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'AdrTools' 'Private' 'Get-AdrDirectory.ps1')
}

Describe 'Get-AdrDirectory' {
    It 'Returns directory from .adr-dir in current directory' {
        $base = Join-Path $TestDrive 'proj1'
        $adrDir = Join-Path $base 'doc' 'adr'
        New-Item -ItemType Directory -Path $adrDir -Force | Out-Null
        Set-Content -Path (Join-Path $base '.adr-dir') -Value 'doc/adr' -NoNewline
        Push-Location $base
        try {
            # Returns absolute path resolved from the dir containing .adr-dir
            Get-AdrDirectory | Should -BeLike '*doc*adr*'
        } finally {
            Pop-Location
        }
    }

    It 'Walks up to find .adr-dir in a parent directory' {
        $base   = Join-Path $TestDrive 'proj2'
        $subDir = Join-Path $base 'src' 'app'
        New-Item -ItemType Directory -Path $subDir -Force | Out-Null
        Set-Content -Path (Join-Path $base '.adr-dir') -Value 'decisions' -NoNewline
        Push-Location $subDir
        try {
            Get-AdrDirectory | Should -BeLike '*decisions*'
        } finally {
            Pop-Location
        }
    }

    It 'Falls back to doc/adr when no .adr-dir is found but doc/adr exists' {
        $base = Join-Path $TestDrive 'proj3'
        $adrDir = Join-Path $base 'doc' 'adr'
        New-Item -ItemType Directory -Path $adrDir -Force | Out-Null
        Push-Location $base
        try {
            Get-AdrDirectory | Should -BeLike '*doc*adr*'
        } finally {
            Pop-Location
        }
    }

    It 'Throws with actionable message when no ADR directory found' {
        $base = Join-Path $TestDrive 'proj4'
        New-Item -ItemType Directory -Path $base | Out-Null
        Push-Location $base
        try {
            { Get-AdrDirectory } | Should -Throw -ExpectedMessage "*No ADR directory found*"
        } finally {
            Pop-Location
        }
    }
}
