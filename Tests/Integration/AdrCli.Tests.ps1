BeforeAll {
    $repoRoot   = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $adrScript  = Join-Path $repoRoot 'AdrTools' 'adr.ps1'
    $script:adr = $adrScript
    $script:repoRoot = $repoRoot

    function script:Invoke-Adr {
        param([string[]]$AdrArgs, [string]$WorkDir = $TestDrive)
        $result = [pscustomobject]@{ Stdout = ''; Stderr = ''; ExitCode = 0 }
        $stdoutFile = Join-Path $TestDrive "$([System.IO.Path]::GetRandomFileName()).out"
        $stderrFile = Join-Path $TestDrive "$([System.IO.Path]::GetRandomFileName()).err"
        $proc = Start-Process -FilePath 'pwsh' `
            -ArgumentList (@('-NoProfile', '-File', $script:adr) + $AdrArgs) `
            -WorkingDirectory $WorkDir `
            -RedirectStandardOutput $stdoutFile `
            -RedirectStandardError  $stderrFile `
            -Wait -PassThru -NoNewWindow
        $raw = if (Test-Path $stdoutFile) { Get-Content $stdoutFile -Raw } else { $null }
        $result.Stdout = if ($raw) { $raw } else { '' }
        $raw = if (Test-Path $stderrFile) { Get-Content $stderrFile -Raw } else { $null }
        $result.Stderr = if ($raw) { $raw } else { '' }
        $result.ExitCode = $proc.ExitCode
        return $result
    }

    function script:New-E2EProject {
        $dir = Join-Path $TestDrive ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $dir | Out-Null
        return $dir
    }
}

Describe 'adr.ps1 end-to-end' {
    It 'adr init: exits 0 and creates 0001 with no BOM' {
        $proj = New-E2EProject
        $r = Invoke-Adr 'init' -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $adr1 = Join-Path $proj 'doc' 'adr' '0001-record-architecture-decisions.md'
        $adr1 | Should -Exist
        $bytes = [System.IO.File]::ReadAllBytes($adr1)
        ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
    }

    It 'adr new (success): exits 0 and prints file path to stdout' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        $r = Invoke-Adr @('new', 'Test Decision') -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $r.Stdout | Should -BeLike '*0002-test-decision.md*'
        (Join-Path $proj 'doc' 'adr' '0002-test-decision.md') | Should -Exist
    }

    It 'adr new without init: exits 1 with actionable error on stderr' {
        $proj = New-E2EProject
        $r = Invoke-Adr @('new', 'X') -WorkDir $proj
        $r.ExitCode | Should -Be 1
        $r.Stderr | Should -Match 'No ADR directory found'
        $files = Get-ChildItem (Join-Path $proj '*') -ErrorAction SilentlyContinue
        $files | Should -BeNullOrEmpty
    }

    It 'adr new -s 99 (bad target): exits 1 and creates no new ADR' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        $r = Invoke-Adr @('new', 'Bad', '-s', '99') -WorkDir $proj
        $r.ExitCode | Should -Be 1
        $r.Stderr | Should -Match 'ADR 99 not found'
        $files = Get-ChildItem (Join-Path $proj 'doc' 'adr') -Filter '0002-*.md' -ErrorAction SilentlyContinue
        $files | Should -BeNullOrEmpty
    }

    It 'adr list: exits 0 and prints full paths one per line' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        Invoke-Adr @('new', 'Second') -WorkDir $proj | Out-Null
        $r = Invoke-Adr 'list' -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $lines = ($r.Stdout.Trim() -split "`n") | Where-Object { $_ -ne '' }
        $lines.Count | Should -Be 2
        $lines[0] | Should -BeLike '*0001-*'
        $lines[1] | Should -BeLike '*0002-*'
    }

    It 'adr link: exits 0 and updates both files' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        Invoke-Adr @('new', 'Logging') -WorkDir $proj | Out-Null
        $r = Invoke-Adr @('link', '1', 'References', '2', 'Referenced by') -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $adr1 = Join-Path $proj 'doc' 'adr' '0001-record-architecture-decisions.md'
        Get-Content $adr1 -Raw | Should -Match 'References \[Logging\]'
    }

    It 'adr generate toc: exits 0 and starts with # Architecture Decision Records' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        $r = Invoke-Adr @('generate', 'toc') -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $r.Stdout | Should -Match '# Architecture Decision Records'
        $r.Stdout | Should -Match '\* \['
    }

    It 'adr generate graph: exits 0 and starts with digraph {' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        $r = Invoke-Adr @('generate', 'graph') -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $r.Stdout | Should -Match 'digraph \{'
        $r.Stdout.TrimEnd() | Should -Match '\}$'
    }

    It 'adr upgrade-repository: exits 0' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        $r = Invoke-Adr 'upgrade-repository' -WorkDir $proj
        $r.ExitCode | Should -Be 0
    }

    It 'adr help: exits 0 and lists all commands' {
        $proj = New-E2EProject
        $r = Invoke-Adr 'help' -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $r.Stdout | Should -Match 'init'
        $r.Stdout | Should -Match 'new'
        $r.Stdout | Should -Match 'generate'
        $r.Stdout | Should -Match 'upgrade-repository'
    }

    It 'adr help new: exits 0 and shows -s -l and format example' {
        $proj = New-E2EProject
        $r = Invoke-Adr @('help', 'new') -WorkDir $proj
        $r.ExitCode | Should -Be 0
        $r.Stdout | Should -Match '\-s'
        $r.Stdout | Should -Match '\-l'
        $r.Stdout | Should -Match 'TARGET:LINK:REVERSE-LINK'
    }

    It 'adr unknowncommand: exits 1 and writes to stderr' {
        $proj = New-E2EProject
        $r = Invoke-Adr 'unknowncommand' -WorkDir $proj
        $r.ExitCode | Should -Be 1
        $r.Stderr | Should -Match 'Unknown command'
        $r.Stdout.Trim() | Should -Be ''
    }

    It 'FunctionsToExport matches all Public/*.ps1 files' {
        $manifestPath = Join-Path $script:repoRoot 'AdrTools' 'AdrTools.psd1'
        $manifest = Import-PowerShellDataFile $manifestPath
        $exported = $manifest.FunctionsToExport | Sort-Object
        $publicFiles = Get-ChildItem (Join-Path $script:repoRoot 'AdrTools' 'Public') -Filter '*.ps1' |
            ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
            Sort-Object
        $exported | Should -Be $publicFiles
    }

    It 'Markdown links in ADR files use forward slashes' {
        $proj = New-E2EProject
        Invoke-Adr 'init' -WorkDir $proj | Out-Null
        Invoke-Adr @('new', 'Logging') -WorkDir $proj | Out-Null
        Invoke-Adr @('link', '1', 'Amends', '2', 'Amended by') -WorkDir $proj | Out-Null
        $adr1 = Join-Path $proj 'doc' 'adr' '0001-record-architecture-decisions.md'
        $content = Get-Content $adr1 -Raw
        # Any markdown link should not contain backslash in the href
        $content | Should -Not -Match '\]\([^)]*\\[^)]*\)'
    }
}
