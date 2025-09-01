<#
.SYNOPSIS
Development helper script to reload the ConvertFromExcel module.

.DESCRIPTION
This script removes the ConvertFromExcel module from memory and imports a fresh
version. This is essential during development since PowerShell caches modules.

.PARAMETER ShowInfo
Display additional information about the module loading process.

.EXAMPLE
.\Reload-Module.ps1
Reloads the module silently

.EXAMPLE
.\Reload-Module.ps1 -ShowInfo
Reloads the module with detailed information

.NOTES
Author: scpg
Date: 2025-09-01
Use this script every time you make changes to the module files.
#>

param(
    [switch]$ShowInfo
)

$ModuleName = "ConvertFromExcel"
$ModulePath = Join-Path $PSScriptRoot "ConvertFromExcel.psd1"

Write-Host "🔄 Reloading $ModuleName module..." -ForegroundColor Cyan

# Check if module file exists
if (-not (Test-Path $ModulePath)) {
    Write-Error "Module file not found: $ModulePath"
    exit 1
}

try {
    # Show current module info if requested
    if ($ShowInfo) {
        $currentModule = Get-Module $ModuleName
        if ($currentModule) {
            Write-Host "📋 Current module info:" -ForegroundColor Yellow
            Write-Host "  Version: $($currentModule.Version)" -ForegroundColor Gray
            Write-Host "  Path: $($currentModule.Path)" -ForegroundColor Gray
            Write-Host "  Functions: $($currentModule.ExportedFunctions.Keys -join ', ')" -ForegroundColor Gray
        } else {
            Write-Host "📋 Module not currently loaded" -ForegroundColor Yellow
        }
    }
    
    # Remove module from memory (suppress errors if not loaded)
    Remove-Module $ModuleName -ErrorAction SilentlyContinue -Force
    
    # Import fresh version
    Import-Module $ModulePath -Force
    
    # Verify successful import
    $loadedModule = Get-Module $ModuleName
    if ($loadedModule) {
        Write-Host "✅ Module reloaded successfully!" -ForegroundColor Green
        
        if ($ShowInfo) {
            Write-Host "📋 Reloaded module info:" -ForegroundColor Yellow
            Write-Host "  Version: $($loadedModule.Version)" -ForegroundColor Gray
            Write-Host "  Path: $($loadedModule.Path)" -ForegroundColor Gray
            Write-Host "  Functions: $($loadedModule.ExportedFunctions.Keys -join ', ')" -ForegroundColor Gray
        }
        
        # Quick function availability check
        $functions = Get-Command -Module $ModuleName
        Write-Host "🔧 Available functions: $($functions.Count)" -ForegroundColor Cyan
        foreach ($func in $functions) {
            Write-Host "  - $($func.Name)" -ForegroundColor Gray
        }
    } else {
        Write-Error "❌ Failed to load module"
        exit 1
    }
}
catch {
    Write-Error "❌ Error reloading module: $($_.Exception.Message)"
    exit 1
}

Write-Host "🎯 Ready for testing! Use the following commands:" -ForegroundColor Green
Write-Host "  # Quick test:" -ForegroundColor Gray
Write-Host "  Get-Command -Module $ModuleName" -ForegroundColor White
Write-Host "  # Run full test suite:" -ForegroundColor Gray
Write-Host "  .\Test-Module.ps1 -CreateTestData -Verbose" -ForegroundColor White