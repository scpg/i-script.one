<#
.SYNOPSIS
    Removes winget managed software matching a name or ID pattern.
.DESCRIPTION
    Queries all installed winget packages, filters by the given pattern,
    shows what will be removed, then uninstalls each matching package.
    Supports -WhatIf to preview and -Force to skip confirmation prompts.
.PARAMETER Pattern
    Required. Filter packages to remove by name or ID (case-insensitive).
    Be as specific as possible to avoid unintended removals.
.PARAMETER Force
    Skip per-package confirmation prompts. Use with caution.
.PARAMETER Quiet
    Suppress the package summary and progress messages.
.EXAMPLE
    .\remove-managedSoftware.ps1 -Pattern "7zip"
.EXAMPLE
    .\remove-managedSoftware.ps1 -Pattern "7zip.7zip" -WhatIf
.EXAMPLE
    .\remove-managedSoftware.ps1 -Pattern "VCRedist" -Force
#>
#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateNotNullOrEmpty()]
    [Alias('p')]
    [string]$Pattern,

    [switch]$Force,

    [Alias('q')]
    [switch]$Quiet
)

# -Force skips per-package confirmation prompts (WhatIf still works normally)
if ($Force) { $ConfirmPreference = 'None' }

# ── Query installed packages ───────────────────────────────────────────────────

Write-Verbose "Querying installed winget packages..."

$allPackages = winget list --source winget --disable-interactivity |
    ForEach-Object {
        if ($_ -match '^\s*(.+?)\s{2,}(\S+)\s+(\S+)') {
            $id = $matches[2]
            if ($id -ne 'Id' -and $id -notmatch '^-+$') {
                [PSCustomObject]@{
                    Name    = $matches[1].Trim()
                    Id      = $id
                    Version = $matches[3]
                }
            }
        }
    } |
    Where-Object { $_ }

Write-Verbose "Total installed packages: $(@($allPackages).Count)"

# ── Filter by pattern ──────────────────────────────────────────────────────────

$safePattern  = [regex]::Escape($Pattern)
$toRemove     = @($allPackages | Where-Object {
    $_.Name -imatch $safePattern -or $_.Id -imatch $safePattern
})

if ($toRemove.Count -eq 0) {
    Write-Warning "No installed packages found matching '$Pattern'."
    exit 0
}

# ── Show what will be removed ──────────────────────────────────────────────────

if (-not $Quiet) {
    Write-Host ""
    Write-Host "Packages matching '$Pattern' ($($toRemove.Count)):" -ForegroundColor Cyan
    Write-Host ("=" * 55) -ForegroundColor Cyan
    $toRemove | Format-Table Name, Id, Version -AutoSize
    Write-Host "!! These packages will be UNINSTALLED !!" -ForegroundColor Red
    Write-Host ""
}

# ── Remove each package ────────────────────────────────────────────────────────

$removed  = 0
$failed   = 0

foreach ($pkg in $toRemove) {
    if ($PSCmdlet.ShouldProcess("$($pkg.Id)  ($($pkg.Name))", "winget uninstall")) {
        if (-not $Quiet) { Write-Host "[INFO] Removing: $($pkg.Id)  ($($pkg.Name))" }
        Write-Verbose "Running: winget uninstall --id $($pkg.Id)"

        if ($VerbosePreference -eq 'Continue') {
            winget uninstall --id $pkg.Id --disable-interactivity --verbose
        } else {
            winget uninstall --id $pkg.Id --disable-interactivity
        }

        if ($LASTEXITCODE -eq 0) {
            $removed++
        } else {
            Write-Warning "winget reported a non-zero exit code for '$($pkg.Id)' (exit: $LASTEXITCODE)."
            $failed++
        }
    }
}

# ── Summary ────────────────────────────────────────────────────────────────────

if (-not $Quiet -and -not $WhatIfPreference) {
    Write-Host ""
    if ($removed -gt 0) { Write-Host "Removed : $removed package(s)." -ForegroundColor Green }
    if ($failed  -gt 0) { Write-Host "Failed  : $failed package(s)." -ForegroundColor Red }
}

Write-Verbose "Done. Removed: $removed  Failed: $failed"
