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
Write-Host ($PROFILE | Get-Member -MemberType NoteProperty | Select-Object Name, Definition | Out-String)

# Check if each profile exists and display its content if it does
$PROFILE | Get-Member -MemberType NoteProperty | ForEach-Object {
    $profilePath = $PROFILE.($_.Name)
    Write-Host "`n=== $($_.Name) ===" -ForegroundColor Cyan
    Write-Host "Path: " -ForegroundColor Cyan -NoNewline
    Write-Host "$profilePath"
    if (Test-Path $profilePath) {
        Write-Host "Status: " -ForegroundColor Cyan -NoNewline
        write-host "EXISTS" -ForegroundColor Green
        $maxWidth = (Get-Content $profilePath | Measure-Object -Property Length -Maximum).Maximum
        $separator = '-' * $maxWidth
        Write-Host "Content:`n$separator" -ForegroundColor Green
        Get-Content $profilePath
        Write-Host "$separator" -ForegroundColor Green
    } else {
        Write-Host "Status: " -ForegroundColor Cyan -NoNewline
        write-host "DOES NOT EXIST" -ForegroundColor Yellow
    }
}
