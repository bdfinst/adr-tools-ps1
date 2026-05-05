BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')
    . (Join-Path $public 'Get-AdrList.ps1')
}

Describe 'Get-AdrList' {
    It 'Returns sorted full paths of all ADR files' {
        $dir = Join-Path $TestDrive 'list-test'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            New-Adr -Title 'Second' | Out-Null
            New-Adr -Title 'Third'  | Out-Null
            $results = Get-AdrList
            $results.Count | Should -Be 3
            $results[0] | Should -BeLike '*0001-*'
            $results[2] | Should -BeLike '*0003-*'
        } finally { Pop-Location }
    }

    It 'Excludes non-ADR files from listing' {
        $dir = Join-Path $TestDrive 'list-excl'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            New-Item -ItemType File -Path (Join-Path $dir 'doc' 'adr' 'README.md') | Out-Null
            $results = Get-AdrList
            $results | Should -Not -BeLike '*README*'
        } finally { Pop-Location }
    }

    It 'Throws with actionable message when no ADR directory exists' {
        $dir = Join-Path $TestDrive 'list-nodir'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            { Get-AdrList } | Should -Throw -ExpectedMessage '*No ADR directory found*'
        } finally { Pop-Location }
    }
}
