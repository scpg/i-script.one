<#
.SYNOPSIS
    Analyzes installed runtime dependencies and redistributables managed by winget.
.DESCRIPTION
    Lists all winget-installed packages, classifies them as runtime dependencies
    (VCRedist, .NET, DirectX, etc.) or regular applications, provides safety
    guidance per category, and prints suggested uninstall commands.
    Never removes anything.
.PARAMETER Pattern
    Filter dependency results to entries whose name or ID match this string
    (case-insensitive).
.PARAMETER Quiet
    Suppress section headers, advice text, and application list.
    Show only the dependency table and uninstall commands.
.EXAMPLE
    .\analyze-dependencies.ps1
.EXAMPLE
    .\analyze-dependencies.ps1 -Pattern VCRedist
.EXAMPLE
    .\analyze-dependencies.ps1 -Verbose
#>
#Requires -Version 5.1
[CmdletBinding()]
param(
    [Alias('p')]
    [string]$Pattern,

    [Alias('q')]
    [switch]$Quiet
)

# Matched against the Package ID column
$depPattern     = 'VCRedist|DotNet|DirectX|XNA|EdgeWebView|OpenAL|PhysX|Redistributable'
$excludeFromApps = 'Microsoft\.UI|WindowsAppRuntime'

# ── Parse winget output ────────────────────────────────────────────────────────

Write-Verbose "Querying all installed winget packages..."

$allPackages = winget list --source winget --disable-interactivity |
    ForEach-Object {
        # Requires 2+ spaces between Name and Id to avoid matching preamble lines
        # (which only have single spaces). Blank lines, headers, separators and
        # the footer naturally fall through.
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

# ── Classify ───────────────────────────────────────────────────────────────────

$dependencies = @($allPackages | Where-Object { $_.Id -match $depPattern })
$applications = @($allPackages | Where-Object { $_.Id -notmatch $depPattern -and $_.Id -notmatch $excludeFromApps })

if ($Pattern) {
    Write-Verbose "Applying filter: '$Pattern'"
    $safe = [regex]::Escape($Pattern)
    $dependencies = @($dependencies | Where-Object { $_.Name -imatch $safe -or $_.Id -imatch $safe })
}

# ── Helpers ────────────────────────────────────────────────────────────────────

function Write-Section ([string]$Title) {
    if ($Quiet) { return }
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host "  $Title" -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

# ── Section 1: Dependencies ────────────────────────────────────────────────────

Write-Section "RUNTIME DEPENDENCIES FOUND ($($dependencies.Count))"

if ($dependencies.Count -gt 0) {
    $dependencies | Format-Table Name, Id, Version -AutoSize
} else {
    Write-Host "  No runtime dependencies found$(if ($Pattern) { " matching '$Pattern'" })." -ForegroundColor Gray
}

# ── Section 2: Recommendations ────────────────────────────────────────────────

if (-not $Quiet) {
    Write-Section "ANALYSIS AND RECOMMENDATIONS"
    Write-Host ""
    Write-Host "  !! Do NOT remove these without careful consideration !!" -ForegroundColor Yellow
    Write-Host ""

    $advice = [ordered]@{
        VCRedist        = "Visual C++ Redistributables  —  required by C++ applications. Multiple versions coexist safely."
        DotNet          = ".NET Runtimes                —  required by .NET apps. Run 'dotnet --list-runtimes' for details."
        DirectX         = "DirectX                      —  usually required for games and graphics software."
        XNA             = "XNA Framework                —  required by older XNA-based games."
        EdgeWebView     = "Edge WebView2                —  required by many modern Windows applications."
        OpenAL          = "OpenAL                       —  required for audio in some games."
        PhysX           = "PhysX                        —  required by NVIDIA PhysX-based games."
        Redistributable = "Other Redistributables       —  research the package ID before removing."
    }

    foreach ($key in $advice.Keys) {
        if ($dependencies | Where-Object { $_.Id -match $key }) {
            Write-Host "  $($advice[$key])" -ForegroundColor White
        }
    }

    # ── Section 3: Applications (cross-reference) ──────────────────────────────

    Write-Section "INSTALLED APPLICATIONS  ($($applications.Count) total — for cross-reference)"
    Write-Host "  Verify none of these depend on a redistributable before uninstalling it." -ForegroundColor Gray
    Write-Host ""
    $applications | Format-Table Name, Id, Version -AutoSize
}

# ── Section 4: Suggested uninstall commands ────────────────────────────────────

Write-Section "SUGGESTED UNINSTALL COMMANDS"
Write-Host ""
Write-Host "  !! USE THE COMMANDS BELOW AT YOUR OWN RISK !!" -ForegroundColor Red
Write-Host "  !! THEY WILL UNINSTALL THE LISTED DEPENDENCIES !!" -ForegroundColor Red
Write-Host ""

if ($dependencies.Count -gt 0) {
    $dependencies | ForEach-Object {
        Write-Host "  winget uninstall --id $($_.Id) --verbose" -ForegroundColor DarkYellow
    }
} else {
    Write-Host "  Nothing to uninstall$(if ($Pattern) { " matching '$Pattern'" })." -ForegroundColor Gray
}

Write-Host ""
Write-Verbose "Analysis complete. $($dependencies.Count) runtime dependencies found."
