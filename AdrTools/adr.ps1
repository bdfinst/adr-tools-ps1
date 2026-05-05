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
        'list' {
            Get-AdrList | ForEach-Object { Write-Host $_ }
        }
        'link' {
            if ($Args.Count -lt 4) {
                [Console]::Error.WriteLine("Usage: adr link SOURCE LINK TARGET REVERSE-LINK")
                exit 1
            }
            Set-AdrLink -Source $Args[0] -LinkText $Args[1] -Target $Args[2] -ReverseLinkText $Args[3]
        }
        'generate' {
            $sub = if ($Args.Count -gt 0) { $Args[0] } else { '' }
            $rest = if ($Args.Count -gt 1) { $Args[1..($Args.Count-1)] } else { @() }
            switch ($sub) {
                'toc' {
                    $prefix = ''; $intro = ''; $outro = ''
                    $j = 0
                    while ($j -lt $rest.Count) {
                        switch ($rest[$j]) {
                            '-p' { $j++; $prefix = $rest[$j] }
                            '-i' { $j++; $intro  = $rest[$j] }
                            '-o' { $j++; $outro  = $rest[$j] }
                        }
                        $j++
                    }
                    Write-Host (Get-AdrToc -Prefix $prefix -Intro $intro -Outro $outro)
                }
                'graph' {
                    $prefix = ''; $ext = '.html'
                    $j = 0
                    while ($j -lt $rest.Count) {
                        switch ($rest[$j]) {
                            '-p' { $j++; $prefix = $rest[$j] }
                            '-e' { $j++; $ext    = $rest[$j] }
                        }
                        $j++
                    }
                    Write-Host (Get-AdrGraph -Prefix $prefix -Extension $ext)
                }
                default {
                    [Console]::Error.WriteLine("Unknown generate subcommand: $sub. Use 'toc' or 'graph'.")
                    exit 1
                }
            }
        }
        'upgrade-repository' {
            Update-AdrRepository
        }
        'help' {
            $cmd = if ($Args.Count -gt 0) { $Args[0] } else { '' }
            Write-Host (Get-AdrHelp -Command $cmd)
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
