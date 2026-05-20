<#
.SYNOPSIS
    Removes winget managed software matching a name or ID pattern.
.DESCRIPTION
    Uses the Microsoft.WinGet.Client module to uninstall packages. Can be run
    standalone (queries all installed packages and filters) or receive piped
    output from list-managedSoftware.ps1.
    Supports -WhatIf to preview and -Force to skip confirmation prompts.
.PARAMETER InputObject
    Package objects piped from list-managedSoftware.ps1.
.PARAMETER Pattern
    Required in standalone mode. Filter packages to remove by name or ID
    (case-insensitive). Be as specific as possible to avoid unintended removals.
    Also applies as a safety filter when receiving pipeline input.
.PARAMETER Force
    Skip per-package confirmation prompts. Use with caution.
.PARAMETER Quiet
    Suppress the package summary and progress messages.
.PARAMETER NoElevate
    Do not attempt to auto-elevate. Exit with an error if not already running
    as Administrator. Use this in pipelines or automation where UAC prompts
    are not acceptable.
.EXAMPLE
    .\remove-managedSoftware.ps1 -Pattern "7zip"
.EXAMPLE
    .\remove-managedSoftware.ps1 -Pattern "7zip.7zip" -WhatIf
.EXAMPLE
    .\remove-managedSoftware.ps1 -Pattern "VCRedist" -Force
.EXAMPLE
    .\list-managedSoftware.ps1 -p vcredist | .\remove-managedSoftware.ps1 -Force
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(ValueFromPipeline)]
    [object]$InputObject,

    [Alias('p')]
    [string]$Pattern,

    [switch]$Force,

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
    # ── Validate: Pattern required in standalone mode ──────────────────────────
    if (-not $pipelineMode -and -not $Pattern) {
        Write-Error "The -Pattern parameter is required in standalone mode. Specify a name or ID to match packages for removal."
        exit 1
    }

    # -Force skips per-package confirmation prompts (WhatIf still works normally)
    if ($Force) { $ConfirmPreference = 'None' }

    # ── Elevation check ────────────────────────────────────────────────────────
    $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

    if (-not $isAdmin) {
        if ($NoElevate) {
            Write-Error "Administrator rights are required to uninstall packages. Run as Administrator, or remove -NoElevate to allow auto-elevation."
            exit 1
        }
        if ($pipelineMode) {
            Write-Error "[ELEVATION REQUIRED] Pipeline mode detected. Start PowerShell as Administrator before running this pipeline."
            exit 1
        }
        Write-Warning "[ELEVATION REQUIRED] Uninstalling software via winget requires Administrator rights.`nA UAC prompt will appear now. Use -NoElevate to manage elevation yourself."
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
        $toRemove = @($pipelinePackages)
    } else {
        Write-Verbose "Querying all installed winget packages..."
        $toRemove = @(Get-WinGetPackage -Source winget)
    }

    if ($Pattern) {
        Write-Verbose "Filtering by: '$Pattern'"
        $safePattern = [regex]::Escape($Pattern)
        $toRemove = @($toRemove | Where-Object {
            $_.Name -imatch $safePattern -or $_.Id -imatch $safePattern
        })
    }

    if ($toRemove.Count -eq 0) {
        Write-Warning "No installed packages found matching '$Pattern'."
        return
    }

    # ── Show what will be removed ──────────────────────────────────────────────
    if (-not $Quiet) {
        Write-Host ""
        $label = if ($Pattern) { "matching '$Pattern'" } else { "from pipeline" }
        Write-Host "Packages $label ($($toRemove.Count)):" -ForegroundColor Cyan
        Write-Host ("=" * 55) -ForegroundColor Cyan
        $toRemove | Format-Table Name, Id, InstalledVersion -AutoSize
        Write-Host "!! These packages will be UNINSTALLED !!" -ForegroundColor Red
        Write-Host ""
    }

    # ── Remove each package ────────────────────────────────────────────────────
    $removed = 0
    $failed  = 0

    foreach ($pkg in $toRemove) {
        if ($PSCmdlet.ShouldProcess("$($pkg.Id)  ($($pkg.Name))", "Uninstall-WinGetPackage")) {
            if (-not $Quiet) { Write-Host "[INFO] Removing: $($pkg.Id)  ($($pkg.Name))" }
            Write-Verbose "Running: Uninstall-WinGetPackage -Id $($pkg.Id) -Mode Silent"
            try {
                Uninstall-WinGetPackage -Id $pkg.Id -Mode Silent -ErrorAction Stop
                $removed++
            } catch {
                Write-Warning "Failed to remove '$($pkg.Id)': $_"
                $failed++
            }
        }
    }

    # ── Summary ────────────────────────────────────────────────────────────────
    if (-not $Quiet -and -not $WhatIfPreference) {
        Write-Host ""
        if ($removed -gt 0) { Write-Host "Removed : $removed package(s)." -ForegroundColor Green }
        if ($failed  -gt 0) { Write-Host "Failed  : $failed package(s)."  -ForegroundColor Red   }
    }

    Write-Verbose "Done. Removed: $removed  Failed: $failed"
}
