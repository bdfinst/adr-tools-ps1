function Get-AdrToc {
    param(
        [string]$Prefix = '',
        [string]$Intro  = '',
        [string]$Outro  = ''
    )

    if ($Intro -and -not (Test-Path $Intro)) {
        throw "Intro file '$Intro' not found."
    }
    if ($Outro -and -not (Test-Path $Outro)) {
        throw "Outro file '$Outro' not found."
    }

    $lines = @('# Architecture Decision Records')

    if ($Intro) {
        $lines += ''
        $lines += Get-Content $Intro
    }

    $lines += ''
    foreach ($adrPath in Get-AdrList) {
        $title    = Get-AdrTitle -Path $adrPath
        $basename = [System.IO.Path]::GetFileName($adrPath)
        $lines += "* [$title]($Prefix$basename)"
    }

    if ($Outro) {
        $lines += ''
        $lines += Get-Content $Outro
    }

    $lines -join "`n"
}
