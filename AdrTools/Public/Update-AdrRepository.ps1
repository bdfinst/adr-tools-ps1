function Update-AdrRepository {
    foreach ($adrPath in Get-AdrList) {
        $lines   = Get-Content $adrPath
        $changed = $false
        $newLines = $lines | ForEach-Object {
            if ($_ -match '^Date:\s+(\d{2})/(\d{2})/(\d{4})\s*$') {
                $changed = $true
                "Date: $($Matches[3])-$($Matches[2])-$($Matches[1])"
            } else { $_ }
        }
        if ($changed) {
            Write-AdrFile -Path $adrPath -Content ($newLines -join "`n")
        }
    }
}
