BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    foreach ($f in Get-ChildItem $private -Filter '*.ps1') { . $f.FullName }
    . (Join-Path $public 'Initialize-AdrDirectory.ps1')
    . (Join-Path $public 'New-Adr.ps1')
    . (Join-Path $public 'Get-AdrList.ps1')
    . (Join-Path $public 'Set-AdrLink.ps1')
}

Describe 'Set-AdrLink' {
    It 'Inserts forward and reverse links bidirectionally' {
        $dir = Join-Path $TestDrive 'setlink-basic'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            New-Adr -Title 'Logging' | Out-Null
            New-Adr -Title 'Tracing' | Out-Null
            Set-AdrLink -Source '2' -LinkText 'Amends' -Target '3' -ReverseLinkText 'Amended by'
            $src = Join-Path $dir 'doc' 'adr' '0002-logging.md'
            $tgt = Join-Path $dir 'doc' 'adr' '0003-tracing.md'
            Get-Content $src -Raw | Should -Match 'Amends \[Tracing\]'
            Get-Content $tgt -Raw | Should -Match 'Amended by \[Logging\]'
        } finally { Pop-Location }
    }

    It 'Fails fast when target does not exist — source unchanged' {
        $dir = Join-Path $TestDrive 'setlink-fail'
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            Initialize-AdrDirectory | Out-Null
            New-Adr -Title 'Logging' | Out-Null
            $srcBefore = Get-Content (Join-Path $dir 'doc' 'adr' '0002-logging.md') -Raw
            { Set-AdrLink -Source '2' -LinkText 'Amends' -Target '99' -ReverseLinkText 'Amended by' } |
                Should -Throw -ExpectedMessage '*ADR 99 not found*'
            $srcAfter = Get-Content (Join-Path $dir 'doc' 'adr' '0002-logging.md') -Raw
            $srcAfter | Should -Be $srcBefore
        } finally { Pop-Location }
    }
}
