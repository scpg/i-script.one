<#
.SYNOPSIS
    Updates winget managed software that has upgrades available.
.DESCRIPTION
    Queries winget for upgradeable packages, optionally filters by name or ID,
    then upgrades each matching package individually.
.PARAMETER Pattern
    Only upgrade packages whose name or ID matches this string (case-insensitive).
.PARAMETER Quiet
    Suppress progress output.
.EXAMPLE
    .\update-managedSoftware.ps1
.EXAMPLE
    .\update-managedSoftware.ps1 -Pattern proton
.EXAMPLE
    .\update-managedSoftware.ps1 -p git -Verbose
.EXAMPLE
    .\update-managedSoftware.ps1 -WhatIf
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [Alias('p')]
    [string]$Pattern,

    [Alias('q')]
    [switch]$Quiet
)

Write-Verbose "Querying packages with available upgrades..."

$packages = winget list --upgrade-available --source winget --disable-interactivity |
    Select-Object -Skip 2 |
    ForEach-Object {
        if ($_ -match '^\s*(.+?)\s{2,}(\S+)\s+(\S+)\s+(\S+)\s*$') {
            $id = $matches[2]
            if ($id -ne 'Id' -and $id -notmatch '^-+$' -and $id -notmatch '^<' -and $_ -notmatch 'upgrades? available') {
                [PSCustomObject]@{
                    Name      = $matches[1].Trim()
                    Id        = $id
                    Version   = $matches[3]
                    Available = $matches[4]
                }
            }
        }
    } |
    Where-Object { $_ }

if ($Pattern) {
    Write-Verbose "Filtering by: '$Pattern'"
    $safePattern = [regex]::Escape($Pattern)
    $packages = $packages | Where-Object {
        $_.Name -imatch $safePattern -or $_.Id -imatch $safePattern
    }
}

if (-not $packages) {
    if (-not $Quiet) { Write-Host "No packages to update." }
    exit 0
}

if (-not $Quiet) {
    Write-Host ""
    Write-Host "Packages to update ($(@($packages).Count)):"
    Write-Host "================================="
    $packages | ForEach-Object {
        Write-Host "  $($_.Id)  ($($_.Name))  $($_.Version) -> $($_.Available)"
    }
    Write-Host ""
}

foreach ($pkg in $packages) {
    if ($PSCmdlet.ShouldProcess($pkg.Id, "winget upgrade")) {
        if (-not $Quiet) { Write-Host "[INFO] Upgrading: $($pkg.Id)" }
        Write-Verbose "Running: winget upgrade --id $($pkg.Id)"

        if ($VerbosePreference -eq 'Continue') {
            winget upgrade --id $pkg.Id --disable-interactivity --accept-package-agreements --verbose
        } else {
            winget upgrade --id $pkg.Id --disable-interactivity --accept-package-agreements
        }
    }
}

Write-Verbose "Done."
