function New-Adr {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position=0, ValueFromRemainingArguments)]
        [string[]]$Title,

        [Alias('s')]
        [string[]]$Supersedes = @(),

        [Alias('l')]
        [string[]]$Link = @()
    )

    $titleStr = $Title -join ' '
    $adrDir   = Get-AdrDirectory

    # Fail-fast: resolve all supersede and link targets BEFORE creating any file
    $supersedeFiles = @()
    foreach ($ref in $Supersedes) {
        $supersedeFiles += Resolve-AdrFile -Ref $ref -AdrDir $adrDir
    }

    $linkTriples = @()
    foreach ($linkSpec in $Link) {
        $parts = $linkSpec -split ':', 3
        if ($parts.Count -lt 3) {
            throw "Invalid -Link format. Expected 'TARGET:LINK:REVERSE-LINK', got: $linkSpec"
        }
        $target = Resolve-AdrFile -Ref $parts[0] -AdrDir $adrDir
        $linkTriples += [pscustomobject]@{
            TargetFile   = $target
            LinkText     = $parts[1]
            ReverseLinkText = $parts[2]
        }
    }

    # Determine new ADR number, filename, and content
    $number   = Get-NextAdrNumber -AdrDir $adrDir
    $slug     = New-AdrSlug -Title $titleStr
    $filename = '{0:D4}-{1}.md' -f [int]$number, $slug
    $adrPath  = Join-Path $adrDir $filename

    $date         = if ($env:ADR_DATE) { $env:ADR_DATE } else { (Get-Date).ToString('yyyy-MM-dd') }
    $templatePath = Resolve-AdrTemplate -AdrDir $adrDir -TemplateType 'template'
    $content      = (Get-Content $templatePath -Raw) `
        -creplace 'NUMBER', $number `
        -creplace 'TITLE',  $titleStr `
        -creplace 'DATE',   $date `
        -creplace 'STATUS', 'Accepted'

    Write-AdrFile -Path $adrPath -Content $content

    # Apply supersedes: update old ADRs and add links to new ADR
    foreach ($oldFile in $supersedeFiles) {
        $oldTitle = Get-AdrTitle -Path $oldFile
        $oldBase  = [System.IO.Path]::GetFileName($oldFile)
        Remove-AdrStatusText -Path $oldFile -Text 'Accepted'
        Add-AdrLink -Path $oldFile -LinkText "Superceded by [$titleStr]($filename)"
        Add-AdrLink -Path $adrPath -LinkText "Supercedes [$oldTitle]($oldBase)"
    }

    # Apply explicit links
    foreach ($triple in $linkTriples) {
        $targetTitle = Get-AdrTitle -Path $triple.TargetFile
        $targetBase  = [System.IO.Path]::GetFileName($triple.TargetFile)
        Add-AdrLink -Path $adrPath           -LinkText "$($triple.LinkText) [$targetTitle]($targetBase)"
        Add-AdrLink -Path $triple.TargetFile -LinkText "$($triple.ReverseLinkText) [$titleStr]($filename)"
    }

    return $adrPath
}
