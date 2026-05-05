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
