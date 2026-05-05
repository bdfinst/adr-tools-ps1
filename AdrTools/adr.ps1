#!/usr/bin/env pwsh
# adr.ps1 — CLI dispatcher for the AdrTools module
[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1, ValueFromRemainingArguments)]
    [string[]]$Args
)

$moduleRoot = $PSScriptRoot
Import-Module (Join-Path $moduleRoot 'AdrTools.psd1') -Force -ErrorAction Stop

try {
    switch ($Command) {
        'init' {
            $dir = if ($Args.Count -gt 0) { $Args[0] } else { 'doc/adr' }
            Initialize-AdrDirectory -Directory $dir
        }
        'new' {
            # Parse -s and -l flags from $Args
            $title      = @()
            $supersedes = @()
            $links      = @()
            $i = 0
            while ($i -lt $Args.Count) {
                switch ($Args[$i]) {
                    { $_ -eq '-s' -or $_ -eq '-Supersedes' } {
                        $i++; $supersedes += $Args[$i]
                    }
                    { $_ -eq '-l' -or $_ -eq '-Link' } {
                        $i++; $links += $Args[$i]
                    }
                    default { $title += $Args[$i] }
                }
                $i++
            }
            if ($title.Count -eq 0) {
                [Console]::Error.WriteLine("Usage: adr new [-s N]... [-l T:LINK:REVERSE]... TITLE...")
                exit 1
            }
            $path = New-Adr -Title $title -Supersedes $supersedes -Link $links
            Write-Host $path
        }
        'help' {
            Write-Host 'adr - Architecture Decision Records tool'
            Write-Host ''
            Write-Host 'Commands: init, new, list, link, generate, upgrade-repository, help'
        }
        default {
            [Console]::Error.WriteLine("Unknown command: $Command")
            exit 1
        }
    }
} catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    exit 1
}
