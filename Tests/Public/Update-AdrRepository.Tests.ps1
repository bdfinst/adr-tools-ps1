BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')
    . (Join-Path $public 'Get-AdrList.ps1')
    . (Join-Path $public 'Update-AdrRepository.ps1')

    function script:New-OldDateAdr {
        param([string]$Dir, [string]$Name, [string]$OldDate)
        $content = "# 2. Old ADR`n`nDate: $OldDate`n`n## Status`n`nAccepted`n`n## Context`n`nText.`n"
        Write-AdrFile -Path (Join-Path $Dir $Name) -Content $content
    }
}

Describe 'Update-AdrRepository' {
    It 'Converts DD/MM/YYYY date to ISO 8601' {
        $dir = Join-Path $TestDrive 'upgrade-basic'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            $adrDir = Join-Path $dir 'doc' 'adr'
            New-OldDateAdr -Dir $adrDir -Name '0002-old.md' -OldDate '15/01/2020'
            Update-AdrRepository
            Get-Content (Join-Path $adrDir '0002-old.md') -Raw | Should -Match 'Date: 2020-01-15'
        } finally { Pop-Location }
    }

    It 'Leaves ISO 8601 date unchanged (idempotent)' {
        $dir = Join-Path $TestDrive 'upgrade-iso'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            $adrDir = Join-Path $dir 'doc' 'adr'
            New-OldDateAdr -Dir $adrDir -Name '0002-iso.md' -OldDate '2020-01-15'
            $before = Get-Content (Join-Path $adrDir '0002-iso.md') -Raw
            Update-AdrRepository
            $after = Get-Content (Join-Path $adrDir '0002-iso.md') -Raw
            $after | Should -Be $before
        } finally { Pop-Location }
    }

    It 'Processes multiple ADR files' {
        $dir = Join-Path $TestDrive 'upgrade-multi'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            $adrDir = Join-Path $dir 'doc' 'adr'
            New-OldDateAdr -Dir $adrDir -Name '0002-a.md' -OldDate '01/03/2019'
            New-OldDateAdr -Dir $adrDir -Name '0003-b.md' -OldDate '15/11/2021'
            Update-AdrRepository
            Get-Content (Join-Path $adrDir '0002-a.md') -Raw | Should -Match 'Date: 2019-03-01'
            Get-Content (Join-Path $adrDir '0003-b.md') -Raw | Should -Match 'Date: 2021-11-15'
        } finally { Pop-Location }
    }
}
