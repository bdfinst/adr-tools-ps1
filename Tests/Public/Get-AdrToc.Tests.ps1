BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')
    . (Join-Path $public 'Get-AdrList.ps1')
    . (Join-Path $public 'Get-AdrToc.ps1')

    function script:New-TocDir {
        $dir = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        Initialize-AdrDirectory | Out-Null
        New-Adr -Title 'Second Decision' | Out-Null
        Pop-Location
        return $dir
    }
}

Describe 'Get-AdrToc' {
    It 'Output begins with # Architecture Decision Records' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            $toc = Get-AdrToc
            ($toc -split "`n")[0] | Should -Be '# Architecture Decision Records'
        } finally { Pop-Location }
    }

    It 'Each ADR appears as a Markdown list item with link' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            $toc = Get-AdrToc
            $toc | Should -Match '\* \[Record architecture decisions\]'
            $toc | Should -Match '\* \[Second Decision\]'
        } finally { Pop-Location }
    }

    It 'Link prefix is prepended to each href' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            $toc = Get-AdrToc -Prefix '/docs/'
            $toc | Should -Match '\[.*\]\(/docs/0001-'
        } finally { Pop-Location }
    }

    It 'Intro file content appears after heading' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            $intro = Join-Path $TestDrive 'intro.md'
            Set-Content -Path $intro -Value 'This is the intro.'
            $toc = Get-AdrToc -Intro $intro
            $lines = $toc -split "`n"
            $introIdx = ($lines | Select-String 'This is the intro\.' | Select-Object -First 1).LineNumber - 1
            $headingIdx = ($lines | Select-String '# Architecture Decision Records' | Select-Object -First 1).LineNumber - 1
            $introIdx | Should -BeGreaterThan $headingIdx
        } finally { Pop-Location }
    }

    It 'Outro file content appears at end' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            $outro = Join-Path $TestDrive 'outro.md'
            Set-Content -Path $outro -Value 'This is the outro.'
            $toc = Get-AdrToc -Outro $outro
            $toc | Should -Match 'This is the outro\.$'
        } finally { Pop-Location }
    }

    It 'Throws when intro file does not exist' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            { Get-AdrToc -Intro (Join-Path $TestDrive 'missing.md') } |
                Should -Throw -ExpectedMessage "*Intro file*not found*"
        } finally { Pop-Location }
    }

    It 'Throws when outro file does not exist' {
        $dir = New-TocDir
        Push-Location $dir
        try {
            { Get-AdrToc -Outro (Join-Path $TestDrive 'missing2.md') } |
                Should -Throw -ExpectedMessage "*Outro file*not found*"
        } finally { Pop-Location }
    }
}
