<#
.SYNOPSIS
Creates sample Excel files for testing the ConvertFromExcel module.

.DESCRIPTION
This script generates various Excel files with different structures to test
all scenarios of the ConvertFromExcel module.

.NOTES
Author: scpg
Date: 2025-09-01
Requires: ImportExcel module
#>

# Check if ImportExcel module is available
if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Error "ImportExcel module is required. Install with: Install-Module ImportExcel"
    exit 1
}

Import-Module ImportExcel

Write-Host "Creating test Excel files..." -ForegroundColor Green

# Ensure test-data directory exists
$testDataPath = Join-Path $PSScriptRoot "test-data"
if (-not (Test-Path $testDataPath)) {
    New-Item -Path $testDataPath -ItemType Directory
}

# 1. Simple data with headers
$simpleData = @(
    [PSCustomObject]@{ Name = "John Doe"; Age = 30; City = "New York" }
    [PSCustomObject]@{ Name = "Jane Smith"; Age = 25; City = "Los Angeles" }
    [PSCustomObject]@{ Name = "Bob Johnson"; Age = 35; City = "Chicago" }
    [PSCustomObject]@{ Name = "Alice Brown"; Age = 28; City = "Houston" }
)

$simpleData | Export-Excel -Path "$testDataPath\simple.xlsx" -AutoSize -BoldTopRow
Write-Host "Created: simple.xlsx (4 rows with headers)" -ForegroundColor Yellow

# 2. Data without headers (raw data)
$rawData = @(
    @("Product1", 100, 25.50)
    @("Product2", 75, 30.00)
    @("Product3", 150, 20.25)
    @("Product4", 90, 35.75)
)

$rawData | Export-Excel -Path "$testDataPath\no-headers.xlsx" -AutoSize
Write-Host "Created: no-headers.xlsx (4 rows without headers)" -ForegroundColor Yellow

# 3. Multiple worksheets
$salesData = @(
    [PSCustomObject]@{ Month = "January"; Revenue = 10000; Units = 100 }
    [PSCustomObject]@{ Month = "February"; Revenue = 12000; Units = 120 }
    [PSCustomObject]@{ Month = "March"; Revenue = 15000; Units = 150 }
)

$inventoryData = @(
    [PSCustomObject]@{ Item = "Widget A"; Stock = 50; Price = 10.99 }
    [PSCustomObject]@{ Item = "Widget B"; Stock = 75; Price = 15.50 }
    [PSCustomObject]@{ Item = "Widget C"; Stock = 25; Price = 8.75 }
)

$customersData = @(
    [PSCustomObject]@{ ID = 1; Customer = "Acme Corp"; Contact = "john@acme.com" }
    [PSCustomObject]@{ ID = 2; Customer = "Beta Inc"; Contact = "jane@beta.com" }
    [PSCustomObject]@{ ID = 3; Customer = "Gamma LLC"; Contact = "bob@gamma.com" }
)

$salesData | Export-Excel -Path "$testDataPath\multiple-sheets.xlsx" -WorksheetName "Sales" -AutoSize -BoldTopRow
$inventoryData | Export-Excel -Path "$testDataPath\multiple-sheets.xlsx" -WorksheetName "Inventory" -AutoSize -BoldTopRow -Append
$customersData | Export-Excel -Path "$testDataPath\multiple-sheets.xlsx" -WorksheetName "Customers" -AutoSize -BoldTopRow -Append
Write-Host "Created: multiple-sheets.xlsx (3 worksheets: Sales, Inventory, Customers)" -ForegroundColor Yellow

# 4. Large dataset for performance testing
$largeData = @()
for ($i = 1; $i -le 1000; $i++) {
    $largeData += [PSCustomObject]@{
        ID = $i
        Name = "User$i"
        Email = "user$i@example.com"
        Department = @("Sales", "Marketing", "IT", "HR", "Finance")[(Get-Random -Maximum 5)]
        Salary = Get-Random -Minimum 30000 -Maximum 120000
        StartDate = (Get-Date).AddDays(-(Get-Random -Maximum 3650))
    }
}

$largeData | Export-Excel -Path "$testDataPath\large-dataset.xlsx" -AutoSize -BoldTopRow
Write-Host "Created: large-dataset.xlsx (1000 rows for performance testing)" -ForegroundColor Yellow

# 5. Empty worksheet
@() | Export-Excel -Path "$testDataPath\empty.xlsx" -WorksheetName "Empty"
Write-Host "Created: empty.xlsx (empty worksheet for edge case testing)" -ForegroundColor Yellow

# 6. Complex data types
$complexData = @(
    [PSCustomObject]@{ 
        Name = "Complex Item 1"
        Numbers = @(1, 2, 3)
        Date = Get-Date
        Boolean = $true
        Null = $null
        Special = "Text with, commas and `"quotes`""
    }
    [PSCustomObject]@{ 
        Name = "Complex Item 2"
        Numbers = @(4, 5, 6)
        Date = (Get-Date).AddDays(-30)
        Boolean = $false
        Null = $null
        Special = "More special chars: !@#$%^&*()"
    }
)

$complexData | Export-Excel -Path "$testDataPath\complex-data.xlsx" -AutoSize -BoldTopRow
Write-Host "Created: complex-data.xlsx (complex data types for robust testing)" -ForegroundColor Yellow

# 7. Different Excel formats (if supported)
$simpleData | Export-Excel -Path "$testDataPath\test.xlsm" -AutoSize -BoldTopRow
Write-Host "Created: test.xlsm (macro-enabled format)" -ForegroundColor Yellow

Write-Host "`nTest data creation completed!" -ForegroundColor Green
Write-Host "Files created in: $testDataPath" -ForegroundColor Cyan

# List all created files
Write-Host "`nCreated test files:" -ForegroundColor Cyan
Get-ChildItem $testDataPath | ForEach-Object {
    Write-Host "  - $($_.Name)" -ForegroundColor White
}