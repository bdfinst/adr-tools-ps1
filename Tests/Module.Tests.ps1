BeforeAll {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $manifestPath = Join-Path $repoRoot 'AdrTools' 'AdrTools.psd1'
    $dispatcherPath = Join-Path $repoRoot 'AdrTools' 'adr.ps1'
    $script:repoRoot = $repoRoot
    $script:manifestPath = $manifestPath
    $script:dispatcherPath = $dispatcherPath
}

Describe 'Module: AdrTools' {
    It 'Module manifest exists' {
        $script:manifestPath | Should -Exist
    }

    It 'Module imports without error' {
        { Import-Module $script:manifestPath -Force -ErrorAction Stop } | Should -Not -Throw
    }

    It 'Module loaded Pester version is >= 5.0.0' {
        $pester = Get-Module Pester
        $pester.Version | Should -BeGreaterOrEqual ([version]'5.0.0')
    }

    It 'adr.ps1 exists' {
        $script:dispatcherPath | Should -Exist
    }
}

Describe 'adr.ps1 dispatcher: stub behaviour' {
    It '"adr help" exits 0' {
        $result = & pwsh -NoProfile -File $script:dispatcherPath help 2>&1
        $LASTEXITCODE | Should -Be 0
    }

    It '"adr unknowncommand" exits non-zero' {
        & pwsh -NoProfile -File $script:dispatcherPath unknowncommand 2>&1 | Out-Null
        $LASTEXITCODE | Should -Not -Be 0
    }
}
