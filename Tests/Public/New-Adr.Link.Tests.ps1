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
        New-Adr -Title 'Use REST' | Out-Null
        Pop-Location
        return $dir
    }
}

Describe 'New-Adr -Link' {
    It 'New ADR Status contains forward link' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            New-Adr -Title 'Add GraphQL Layer' -Link @('2:Amends:Amended by') | Out-Null
            $newFile = Join-Path $dir 'doc' 'adr' '0003-add-graphql-layer.md'
            Get-Content $newFile -Raw | Should -Match 'Amends \[Use REST\]'
        } finally { Pop-Location }
    }

    It 'Target ADR Status contains reverse link' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            New-Adr -Title 'Add GraphQL Layer' -Link @('2:Amends:Amended by') | Out-Null
            $targetFile = Join-Path $dir 'doc' 'adr' '0002-use-rest.md'
            Get-Content $targetFile -Raw | Should -Match 'Amended by \[Add GraphQL Layer\]'
        } finally { Pop-Location }
    }

    It 'Fails fast when link target does not exist — no new file created' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            { New-Adr -Title 'Fail' -Link @('99:Amends:Amended by') } |
                Should -Throw -ExpectedMessage '*ADR 99 not found*'
            $files = Get-ChildItem (Join-Path $dir 'doc' 'adr') -Filter '000[3-9]-*.md'
            $files | Should -BeNullOrEmpty
        } finally { Pop-Location }
    }

    It 'Fails with actionable message on invalid -Link format' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            { New-Adr -Title 'Fail' -Link @('invalid-no-colons') } |
                Should -Throw -ExpectedMessage '*Invalid -Link format*'
        } finally { Pop-Location }
    }

    It 'Combines -Supersedes and -Link in one call' {
        $dir = New-InitedDirWith2Adrs
        Push-Location $dir
        try {
            New-Adr -Title 'Combo' -Supersedes @('2') -Link @('2:Refines:Refined by') | Out-Null
            $oldFile = Join-Path $dir 'doc' 'adr' '0002-use-rest.md'
            $content = Get-Content $oldFile -Raw
            $content | Should -Match 'Superceded by'
            $content | Should -Match 'Refined by'
        } finally { Pop-Location }
    }
}
