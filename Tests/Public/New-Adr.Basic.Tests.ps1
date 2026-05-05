BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')

    function script:New-InitedDir {
        $dir = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        Initialize-AdrDirectory | Out-Null
        Pop-Location
        return $dir
    }
}

Describe 'New-Adr basic creation' {
    It 'Creates file with 4-digit padded filename' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            New-Adr -Title 'Use PostgreSQL for the database' | Out-Null
            (Join-Path $dir 'doc' 'adr' '0002-use-postgresql-for-the-database.md') | Should -Exist
        } finally { Pop-Location }
    }

    It 'Heading uses bare integer (not zero-padded)' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            New-Adr -Title 'My Decision' | Out-Null
            $file = Join-Path $dir 'doc' 'adr' '0002-my-decision.md'
            $content = Get-Content $file -Raw
            $content | Should -Match '^# 2\. My Decision'
        } finally { Pop-Location }
    }

    It 'Contains today ISO date by default' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            New-Adr -Title 'My Decision' | Out-Null
            $file = Join-Path $dir 'doc' 'adr' '0002-my-decision.md'
            $content = Get-Content $file -Raw
            $today = (Get-Date).ToString('yyyy-MM-dd')
            $content | Should -Match "Date: $today"
        } finally { Pop-Location }
    }

    It 'Respects ADR_DATE env var' {
        $dir = New-InitedDir
        $env:ADR_DATE = '2020-01-15'
        Push-Location $dir
        try {
            New-Adr -Title 'My Decision' | Out-Null
            $file = Join-Path $dir 'doc' 'adr' '0002-my-decision.md'
            Get-Content $file -Raw | Should -Match 'Date: 2020-01-15'
        } finally {
            Pop-Location
            Remove-Item Env:ADR_DATE -ErrorAction SilentlyContinue
        }
    }

    It 'Status section contains Accepted' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            New-Adr -Title 'My Decision' | Out-Null
            $file = Join-Path $dir 'doc' 'adr' '0002-my-decision.md'
            Get-Content $file -Raw | Should -Match 'Accepted'
        } finally { Pop-Location }
    }

    It 'Contains required sections' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            New-Adr -Title 'My Decision' | Out-Null
            $file = Join-Path $dir 'doc' 'adr' '0002-my-decision.md'
            $content = Get-Content $file -Raw
            $content | Should -Match '## Context'
            $content | Should -Match '## Decision'
            $content | Should -Match '## Consequences'
        } finally { Pop-Location }
    }

    It 'Returns/outputs the created file path' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            $result = New-Adr -Title 'My Decision'
            $result | Should -BeLike '*0002-my-decision.md'
        } finally { Pop-Location }
    }

    It 'File has no BOM' {
        $dir = New-InitedDir
        Push-Location $dir
        try {
            $path = New-Adr -Title 'My Decision'
            $bytes = [System.IO.File]::ReadAllBytes($path)
            ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
        } finally { Pop-Location }
    }

    It 'Throws when no ADR directory configured' {
        $dir = Join-Path $TestDrive 'no-init-dir'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            { New-Adr -Title 'X' } | Should -Throw -ExpectedMessage '*No ADR directory found*'
        } finally { Pop-Location }
    }
}
