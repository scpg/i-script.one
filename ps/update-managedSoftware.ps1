<#
.SYNOPSIS
    Updates winget managed software that has upgrades available.
.DESCRIPTION
    Uses the Microsoft.WinGet.Client module to upgrade packages. Can be run
    standalone (queries winget internally) or receive piped output from
    list-managedSoftware.ps1 for filtered upgrades.
.PARAMETER InputObject
    Package objects piped from list-managedSoftware.ps1.
.PARAMETER Pattern
    Only upgrade packages whose name or ID matches this string (case-insensitive).
    Ignored when receiving pipeline input unless specified explicitly as an
    additional safety filter.
.PARAMETER Quiet
    Suppress progress output.
.PARAMETER NoElevate
    Do not attempt to auto-elevate. Exit with an error if not already running
    as Administrator. Use this in pipelines or automation where UAC prompts
    are not acceptable.
.EXAMPLE
    .\update-managedSoftware.ps1
.EXAMPLE
    .\update-managedSoftware.ps1 -Pattern proton
.EXAMPLE
    .\update-managedSoftware.ps1 -WhatIf
.EXAMPLE
    .\list-managedSoftware.ps1 -p git | .\update-managedSoftware.ps1
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ValueFromPipeline)]
    [object]$InputObject,

    [Alias('p')]
    [string]$Pattern,

    [Alias('q')]
    [switch]$Quiet,

    [switch]$NoElevate
)

begin {
    if (-not (Get-Module -Name Microsoft.WinGet.Client -ListAvailable -ErrorAction SilentlyContinue)) {
        Write-Error "Microsoft.WinGet.Client module not found. Install with: Install-Module Microsoft.WinGet.Client -Scope CurrentUser"
        exit 1
    }
    Import-Module Microsoft.WinGet.Client

    $pipelineMode     = $false
    $pipelinePackages = [System.Collections.Generic.List[object]]::new()
}

process {
    if ($InputObject) {
        $pipelineMode = $true
        $pipelinePackages.Add($InputObject)
    }
}

end {
    # ── Elevation check ────────────────────────────────────────────────────────
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        if ($NoElevate) {
            Write-Error "Administrator rights are required to upgrade packages. Run as Administrator, or remove -NoElevate to allow auto-elevation."
            exit 1
        }
        if ($pipelineMode) {
            Write-Error "[ELEVATION REQUIRED] Pipeline mode detected. Start PowerShell as Administrator before running this pipeline."
            exit 1
        }
        Write-Warning "[ELEVATION REQUIRED] Upgrading software via winget requires Administrator rights.`nA UAC prompt will appear now. Use -NoElevate to manage elevation yourself."
        $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
        foreach ($key in $PSBoundParameters.Keys) {
            $val = $PSBoundParameters[$key]
            if ($val -is [switch]) { if ($val) { $argList += "-$key" } }
            else { $argList += "-$key", "`"$val`"" }
        }
        Start-Process pwsh -Verb RunAs -ArgumentList $argList
        exit
    }

    # ── Resolve package list ───────────────────────────────────────────────────
    if ($pipelineMode) {
        Write-Verbose "Using $($pipelinePackages.Count) package(s) from pipeline."
        $packages = $pipelinePackages
    } else {
        Write-Verbose "Querying packages with available upgrades..."
        $packages = Get-WinGetPackage -Source winget | Where-Object { $_.IsUpdateAvailable }
    }

    if ($Pattern) {
        Write-Verbose "Filtering by: '$Pattern'"
        $safePattern = [regex]::Escape($Pattern)
        $packages = @($packages | Where-Object {
            $_.Name -imatch $safePattern -or $_.Id -imatch $safePattern
        })
    }

    if (-not $packages) {
        if (-not $Quiet) { Write-Host "No packages to update." }
        return
    }

    # ── Preview ────────────────────────────────────────────────────────────────
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "Packages to update ($(@($packages).Count)):"
        Write-Host "================================="
        $packages | ForEach-Object {
            $avail = if ($_.PSObject.Properties['Available']) { $_.Available }
                     elseif ($_.AvailableVersions)            { $_.AvailableVersions[0] }
                     else                                     { '?' }
            Write-Host "  $($_.Id)  ($($_.Name))  $($_.InstalledVersion) -> $avail"
        }
        Write-Host ""
    }

    # ── Upgrade ────────────────────────────────────────────────────────────────
    $updated = 0
    $failed  = 0

    foreach ($pkg in $packages) {
        if ($PSCmdlet.ShouldProcess($pkg.Id, "Update-WinGetPackage")) {
            if (-not $Quiet) { Write-Host "[INFO] Upgrading: $($pkg.Id)" }
            Write-Verbose "Running: Update-WinGetPackage -Id $($pkg.Id) -Mode Silent"
            try {
                Update-WinGetPackage -Id $pkg.Id -Mode Silent -ErrorAction Stop
                $updated++
            } catch {
                Write-Warning "Failed to upgrade '$($pkg.Id)': $_"
                $failed++
            }
        }
    }

    # ── Summary ────────────────────────────────────────────────────────────────
    if (-not $Quiet -and -not $WhatIfPreference) {
        Write-Host ""
        if ($updated -gt 0) { Write-Host "Updated : $updated package(s)." -ForegroundColor Green }
        if ($failed  -gt 0) { Write-Host "Failed  : $failed package(s)."  -ForegroundColor Red   }
    }

    Write-Verbose "Done. Updated: $updated  Failed: $failed"
}
