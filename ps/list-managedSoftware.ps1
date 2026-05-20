<#
.SYNOPSIS
    Lists winget managed software that has upgrades available.
.DESCRIPTION
    Uses the Microsoft.WinGet.Client module to query upgradeable packages and
    emits structured objects (Name, Id, InstalledVersion, Available). Output is
    pipeline-friendly — pipe to update-managedSoftware.ps1 or
    remove-managedSoftware.ps1.
.PARAMETER Pattern
    Filter results by package name or ID (case-insensitive).
.PARAMETER Quiet
    Suppress informational messages. Object output is unaffected.
.EXAMPLE
    .\list-managedSoftware.ps1
.EXAMPLE
    .\list-managedSoftware.ps1 -Pattern proton
.EXAMPLE
    .\list-managedSoftware.ps1 -p git | .\update-managedSoftware.ps1
.EXAMPLE
    .\list-managedSoftware.ps1 -p vcredist | .\remove-managedSoftware.ps1 -Force
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Alias('p')]
    [string]$Pattern,

    [Alias('q')]
    [switch]$Quiet
)

if (-not (Get-Module -Name Microsoft.WinGet.Client -ListAvailable -ErrorAction SilentlyContinue)) {
    Write-Error "Microsoft.WinGet.Client module not found. Install with: Install-Module Microsoft.WinGet.Client -Scope CurrentUser"
    exit 1
}
Import-Module Microsoft.WinGet.Client

Write-Verbose "Querying upgradeable packages from winget source..."

$packages = Get-WinGetPackage -Source winget | Where-Object { $_.IsUpdateAvailable }

if ($Pattern) {
    Write-Verbose "Filtering by: '$Pattern'"
    $safePattern = [regex]::Escape($Pattern)
    $packages = @($packages | Where-Object {
        $_.Name -imatch $safePattern -or $_.Id -imatch $safePattern
    })
}

if (-not $Quiet) {
    Write-Verbose "Found $(@($packages).Count) package(s) with upgrades available."
}

$packages | ForEach-Object {
    [PSCustomObject]@{
        Name             = $_.Name
        Id               = $_.Id
        InstalledVersion = $_.InstalledVersion
        Available        = $_.AvailableVersions[0]
    }
}
