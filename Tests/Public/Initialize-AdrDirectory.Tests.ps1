BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $private  = Join-Path $repoRoot 'AdrTools' 'Private'
    $public   = Join-Path $repoRoot 'AdrTools' 'Public'
    . (Join-Path $private 'Write-AdrFile.ps1')
    . (Join-Path $private 'Get-AdrDirectory.ps1')
    . (Join-Path $private 'Get-AdrStatusBounds.ps1')
    . (Join-Path $private 'Get-NextAdrNumber.ps1')
    . (Join-Path $private 'New-AdrSlug.ps1')
    . (Join-Path $private 'Resolve-AdrTemplate.ps1')
    . (Join-Path $public  'Initialize-AdrDirectory.ps1')
    $script:repoRoot = $repoRoot
}

Describe 'Resolve-AdrTemplate' {
    It 'Returns built-in template path when no override exists' {
        $dir = Join-Path $TestDrive 'no-override'
        New-Item -ItemType Directory -Path $dir | Out-Null
        $result = Resolve-AdrTemplate -AdrDir $dir -TemplateType 'template'
        $result | Should -BeLike '*AdrTools*templates*template.md'
    }

    It 'Returns ADR_TEMPLATE env var path when set' {
        $custom = Join-Path $TestDrive 'my-template.md'
        Set-Content -Path $custom -Value '# Custom'
        $env:ADR_TEMPLATE = $custom
        try {
            $result = Resolve-AdrTemplate -AdrDir (Join-Path $TestDrive 'x') -TemplateType 'template'
            $result | Should -Be $custom
        } finally {
            Remove-Item Env:ADR_TEMPLATE -ErrorAction SilentlyContinue
        }
    }

    It 'Throws when ADR_TEMPLATE points to missing file' {
        $env:ADR_TEMPLATE = Join-Path $TestDrive 'missing.md'
        try {
            { Resolve-AdrTemplate -AdrDir (Join-Path $TestDrive 'x') -TemplateType 'template' } |
                Should -Throw -ExpectedMessage '*Template file not found*'
        } finally {
            Remove-Item Env:ADR_TEMPLATE -ErrorAction SilentlyContinue
        }
    }

    It 'Uses adr-dir/templates/template.md when present' {
        $dir = Join-Path $TestDrive 'custom-tpl'
        $tplDir = Join-Path $dir 'templates'
        New-Item -ItemType Directory -Path $tplDir -Force | Out-Null
        Set-Content -Path (Join-Path $tplDir 'template.md') -Value '# Custom'
        $result = Resolve-AdrTemplate -AdrDir $dir -TemplateType 'template'
        $result | Should -BeLike "*$dir*template.md"
    }
}

Describe 'Initialize-AdrDirectory' {
    It 'Creates doc/adr and .adr-dir by default' {
        $base = Join-Path $TestDrive 'init-default'
        New-Item -ItemType Directory -Path $base | Out-Null
        Push-Location $base
        try {
            Initialize-AdrDirectory
            (Join-Path $base 'doc' 'adr') | Should -Exist
            (Join-Path $base '.adr-dir') | Should -Exist
            Get-Content (Join-Path $base '.adr-dir') | Should -Be 'doc/adr'
        } finally { Pop-Location }
    }

    It 'Creates custom directory and writes .adr-dir' {
        $base = Join-Path $TestDrive 'init-custom'
        New-Item -ItemType Directory -Path $base | Out-Null
        Push-Location $base
        try {
            Initialize-AdrDirectory -Directory 'decisions'
            (Join-Path $base 'decisions') | Should -Exist
            Get-Content (Join-Path $base '.adr-dir') | Should -Be 'decisions'
        } finally { Pop-Location }
    }

    It 'Creates 0001-record-architecture-decisions.md with Accepted status' {
        $base = Join-Path $TestDrive 'init-adr1'
        New-Item -ItemType Directory -Path $base | Out-Null
        Push-Location $base
        try {
            Initialize-AdrDirectory
            $adr1 = Join-Path $base 'doc' 'adr' '0001-record-architecture-decisions.md'
            $adr1 | Should -Exist
            $content = Get-Content $adr1 -Raw
            $content | Should -Match 'Accepted'
        } finally { Pop-Location }
    }

    It 'Does not clobber existing ADRs on re-init' {
        $base = Join-Path $TestDrive 'init-reinit'
        New-Item -ItemType Directory -Path $base | Out-Null
        Push-Location $base
        try {
            Initialize-AdrDirectory
            $adr1 = Join-Path $base 'doc' 'adr' '0001-record-architecture-decisions.md'
            $orig = Get-Content $adr1 -Raw
            Initialize-AdrDirectory
            Get-Content $adr1 -Raw | Should -Be $orig
        } finally { Pop-Location }
    }

    It 'Creates ADR file with no BOM' {
        $base = Join-Path $TestDrive 'init-nobom'
        New-Item -ItemType Directory -Path $base | Out-Null
        Push-Location $base
        try {
            Initialize-AdrDirectory
            $adr1 = Join-Path $base 'doc' 'adr' '0001-record-architecture-decisions.md'
            $bytes = [System.IO.File]::ReadAllBytes($adr1)
            ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) | Should -Be $false
        } finally { Pop-Location }
    }
}
