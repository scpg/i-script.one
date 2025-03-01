<#
.SYNOPSIS
Displays all PowerShell profile paths and their contents.

.DESCRIPTION
This script lists all PowerShell profile paths and checks if each profile exists.
If a profile exists, it displays its content.

.NOTES
Author: scpg
Version: 1.0
Date: 2025-01-17
License: MIT License (https://opensource.org/licenses/MIT)
Created with assistance from Claude.ai

.LINK
https://github.com/scpg/i-script.one
#>

# Display all PowerShell profile paths
$PROFILE | Get-Member -MemberType NoteProperty | Select-Object Name, Definition

# Check if each profile exists and display its content if it does
$PROFILE | Get-Member -MemberType NoteProperty | ForEach-Object {
    $profilePath = $PROFILE.($_.Name)
    Write-Host "`n=== $($_.Name) ===" -ForegroundColor Cyan
    Write-Host "Path: $profilePath"
    if (Test-Path $profilePath) {
        Write-Host "Status: EXISTS" -ForegroundColor Green
        Write-Host "Content:`n-----------"
        Get-Content $profilePath
        Write-Host "-----------"
    } else {
        Write-Host "Status: DOES NOT EXIST" -ForegroundColor Yellow
    }
}
