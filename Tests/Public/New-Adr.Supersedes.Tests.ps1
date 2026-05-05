BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')

    function script:New-InitedDirWith2Adrs {
        $dir = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        Initialize-AdrDirectory | Out-Null
        New-Adr -Title 'Use MySQL' | Out-Null
        Pop-Location
        return $dir
    }
}

Describe 'New-Adr -Supersedes' {
    It 'New ADR Status contains Supercedes link to old ADR' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            New-Adr -Title 'Replace MySQL with SQLite' -Supersedes @('2') | Out-Null
            $newFile = Join-Path $dir 'doc' 'adr' '0003-replace-mysql-with-sqlite.md'
            Get-Content $newFile -Raw | Should -Match 'Supercedes \[Use MySQL\]'
        } finally { Pop-Location }
    }

    It 'Old ADR Status loses Accepted and gains Superceded by link' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            New-Adr -Title 'Replace MySQL with SQLite' -Supersedes @('2') | Out-Null
            $oldFile = Join-Path $dir 'doc' 'adr' '0002-use-mysql.md'
            $content = Get-Content $oldFile -Raw
            $content | Should -Not -Match '^Accepted$'
            $content | Should -Match 'Superceded by \[Replace MySQL with SQLite\]'
        } finally { Pop-Location }
    }

    It 'Supports partial name match for supersede reference' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            New-Adr -Title 'New DB' -Supersedes @('mysql') | Out-Null
            $oldFile = Join-Path $dir 'doc' 'adr' '0002-use-mysql.md'
            Get-Content $oldFile -Raw | Should -Match 'Superceded by'
        } finally { Pop-Location }
    }

    It 'Fails fast when supersede target does not exist — no new file created' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            { New-Adr -Title 'Fail' -Supersedes @('99') } |
                Should -Throw -ExpectedMessage '*ADR 99 not found*'
            # No new ADR beyond 0002 should exist
            $files = Get-ChildItem (Join-Path $dir 'doc' 'adr') -Filter '000[3-9]-*.md'
            $files | Should -BeNullOrEmpty
        } finally { Pop-Location }
    }
}
