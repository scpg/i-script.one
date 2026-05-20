<#
.SYNOPSIS
    Lists winget managed software that has upgrades available.
.DESCRIPTION
    Runs winget list --upgrade-available and optionally filters by package name or ID.
.PARAMETER Pattern
    Filter results by package name or ID (case-insensitive).
.PARAMETER Quiet
    Suppress winget preamble and footer, show only package data lines.
.EXAMPLE
    .\list-managedSoftware.ps1
.EXAMPLE
    .\list-managedSoftware.ps1 -Pattern proton
.EXAMPLE
    .\list-managedSoftware.ps1 -p git -Verbose
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Alias('p')]
    [string]$Pattern,

    [Alias('q')]
    [switch]$Quiet
)

Write-Verbose "Running: winget list --upgrade-available --source winget"

$lines = winget list --upgrade-available --source winget --disable-interactivity

if ($Pattern) {
    Write-Verbose "Filtering by: '$Pattern'"
    $lines = $lines | Where-Object { $_ -imatch [regex]::Escape($Pattern) }
}

if ($Quiet) {
    $lines | Where-Object {
        $_ -ne '' -and
        $_ -notmatch '^Windows Package Manager' -and
        $_ -notmatch '^Copyright' -and
        $_ -notmatch '\d+ upgrades? available'
    }
} else {
    $lines
}
