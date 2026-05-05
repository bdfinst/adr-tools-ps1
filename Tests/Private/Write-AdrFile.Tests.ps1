BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    . (Join-Path $repoRoot 'AdrTools' 'Private' 'Write-AdrFile.ps1')
}

Describe 'Write-AdrFile' {
    BeforeEach {
        $testFile = Join-Path $TestDrive 'test.md'
    }

    It 'Creates a file with given content' {
        Write-AdrFile -Path $testFile -Content "hello`nworld"
        $testFile | Should -Exist
    }

    It 'Writes no BOM (first 3 bytes are not EF BB BF)' {
        Write-AdrFile -Path $testFile -Content "# Title`n"
        $bytes = [System.IO.File]::ReadAllBytes($testFile)
        ($bytes.Count -ge 3) | Should -Be $true
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
    }

    It 'Writes LF-only line endings (no CR bytes)' {
        Write-AdrFile -Path $testFile -Content "line1`nline2`nline3"
        $bytes = [System.IO.File]::ReadAllBytes($testFile)
        $bytes | Should -Not -Contain 0x0D
    }

    It 'Overwrites an existing file' {
        Write-AdrFile -Path $testFile -Content 'original'
        Write-AdrFile -Path $testFile -Content 'replaced'
        [System.IO.File]::ReadAllText($testFile) | Should -Be 'replaced'
    }

    It 'Normalizes CRLF input to LF' {
        Write-AdrFile -Path $testFile -Content "a`r`nb"
        $bytes = [System.IO.File]::ReadAllBytes($testFile)
        $bytes | Should -Not -Contain 0x0D
        [System.IO.File]::ReadAllText($testFile) | Should -Be "a`nb"
    }

    It 'Normalizes bare-CR input to LF' {
        Write-AdrFile -Path $testFile -Content "a`rb"
        $bytes = [System.IO.File]::ReadAllBytes($testFile)
        $bytes | Should -Not -Contain 0x0D
        [System.IO.File]::ReadAllText($testFile) | Should -Be "a`nb"
    }
}
