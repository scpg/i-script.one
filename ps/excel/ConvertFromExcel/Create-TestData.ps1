<#
.SYNOPSIS
Creates sample Excel files for testing the ConvertFromExcel module using native Excel COM objects.

.DESCRIPTION
This script generates various Excel files with different structures to test
all scenarios of the ConvertFromExcel module using only native Microsoft tools.

.NOTES
Author: scpg
Date: 2025-09-01
Requires: Microsoft Excel installed (uses COM objects)
#>

# Check if Excel is available
function Test-ExcelAvailability {
    try {
        $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

if (-not (Test-ExcelAvailability)) {
    Write-Error "Microsoft Excel is not installed or accessible. This script requires Excel COM objects."
    exit 1
}

Write-Host "Creating test Excel files using native Excel COM objects..." -ForegroundColor Green

# Ensure test-data directory exists
$testDataPath = Join-Path $PSScriptRoot "test-data"
if (-not (Test-Path $testDataPath)) {
    New-Item -Path $testDataPath -ItemType Directory
}

$excel = $null

try {
    # Create Excel application
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $excel.ScreenUpdating = $false

    # 1. Simple data with headers
    Write-Host "Creating: simple.xlsx (4 rows with headers)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "Data"
    
    # Headers
    $worksheet.Cells.Item(1, 1) = "Name"
    $worksheet.Cells.Item(1, 2) = "Age"
    $worksheet.Cells.Item(1, 3) = "City"
    
    # Data
    $worksheet.Cells.Item(2, 1) = "John Doe"
    $worksheet.Cells.Item(2, 2) = 30
    $worksheet.Cells.Item(2, 3) = "New York"
    
    $worksheet.Cells.Item(3, 1) = "Jane Smith"
    $worksheet.Cells.Item(3, 2) = 25
    $worksheet.Cells.Item(3, 3) = "Los Angeles"
    
    $worksheet.Cells.Item(4, 1) = "Bob Johnson"
    $worksheet.Cells.Item(4, 2) = 35
    $worksheet.Cells.Item(4, 3) = "Chicago"
    
    $worksheet.Cells.Item(5, 1) = "Alice Brown"
    $worksheet.Cells.Item(5, 2) = 28
    $worksheet.Cells.Item(5, 3) = "Houston"
    
    # Format headers
    $headerRange = $worksheet.Range("A1:C1")
    $headerRange.Font.Bold = $true
    $headerRange.Interior.Color = 15123456  # Light blue
    
    # Auto-fit columns
    $worksheet.Columns.AutoFit() | Out-Null
    
    $workbook.SaveAs("$testDataPath\simple.xlsx")
    $workbook.Close()

    # 2. Data without headers
    Write-Host "Creating: no-headers.xlsx (4 rows without headers)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "RawData"
    
    # Raw data without headers
    $worksheet.Cells.Item(1, 1) = "Product1"
    $worksheet.Cells.Item(1, 2) = 100
    $worksheet.Cells.Item(1, 3) = 25.50
    
    $worksheet.Cells.Item(2, 1) = "Product2"
    $worksheet.Cells.Item(2, 2) = 75
    $worksheet.Cells.Item(2, 3) = 30.00
    
    $worksheet.Cells.Item(3, 1) = "Product3"
    $worksheet.Cells.Item(3, 2) = 150
    $worksheet.Cells.Item(3, 3) = 20.25
    
    $worksheet.Cells.Item(4, 1) = "Product4"
    $worksheet.Cells.Item(4, 2) = 90
    $worksheet.Cells.Item(4, 3) = 35.75
    
    $worksheet.Columns.AutoFit() | Out-Null
    
    $workbook.SaveAs("$testDataPath\no-headers.xlsx")
    $workbook.Close()

    # 3. Multiple worksheets
    Write-Host "Creating: multiple-sheets.xlsx (3 worksheets: Sales, Inventory, Customers)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    
    # Sales worksheet
    $salesWS = $workbook.Worksheets.Item(1)
    $salesWS.Name = "Sales"
    
    $salesWS.Cells.Item(1, 1) = "Month"
    $salesWS.Cells.Item(1, 2) = "Revenue"
    $salesWS.Cells.Item(1, 3) = "Units"
    
    $salesWS.Cells.Item(2, 1) = "January"
    $salesWS.Cells.Item(2, 2) = 10000
    $salesWS.Cells.Item(2, 3) = 100
    
    $salesWS.Cells.Item(3, 1) = "February"
    $salesWS.Cells.Item(3, 2) = 12000
    $salesWS.Cells.Item(3, 3) = 120
    
    $salesWS.Cells.Item(4, 1) = "March"
    $salesWS.Cells.Item(4, 2) = 15000
    $salesWS.Cells.Item(4, 3) = 150
    
    $salesWS.Range("A1:C1").Font.Bold = $true
    $salesWS.Columns.AutoFit() | Out-Null
    
    # Add Inventory worksheet
    $inventoryWS = $workbook.Worksheets.Add()
    $inventoryWS.Name = "Inventory"
    
    $inventoryWS.Cells.Item(1, 1) = "Item"
    $inventoryWS.Cells.Item(1, 2) = "Stock"
    $inventoryWS.Cells.Item(1, 3) = "Price"
    
    $inventoryWS.Cells.Item(2, 1) = "Widget A"
    $inventoryWS.Cells.Item(2, 2) = 50
    $inventoryWS.Cells.Item(2, 3) = 10.99
    
    $inventoryWS.Cells.Item(3, 1) = "Widget B"
    $inventoryWS.Cells.Item(3, 2) = 75
    $inventoryWS.Cells.Item(3, 3) = 15.50
    
    $inventoryWS.Cells.Item(4, 1) = "Widget C"
    $inventoryWS.Cells.Item(4, 2) = 25
    $inventoryWS.Cells.Item(4, 3) = 8.75
    
    $inventoryWS.Range("A1:C1").Font.Bold = $true
    $inventoryWS.Columns.AutoFit() | Out-Null
    
    # Add Customers worksheet
    $customersWS = $workbook.Worksheets.Add()
    $customersWS.Name = "Customers"
    
    $customersWS.Cells.Item(1, 1) = "ID"
    $customersWS.Cells.Item(1, 2) = "Customer"
    $customersWS.Cells.Item(1, 3) = "Contact"
    
    $customersWS.Cells.Item(2, 1) = 1
    $customersWS.Cells.Item(2, 2) = "Acme Corp"
    $customersWS.Cells.Item(2, 3) = "john@acme.com"
    
    $customersWS.Cells.Item(3, 1) = 2
    $customersWS.Cells.Item(3, 2) = "Beta Inc"
    $customersWS.Cells.Item(3, 3) = "jane@beta.com"
    
    $customersWS.Cells.Item(4, 1) = 3
    $customersWS.Cells.Item(4, 2) = "Gamma LLC"
    $customersWS.Cells.Item(4, 3) = "bob@gamma.com"
    
    $customersWS.Range("A1:C1").Font.Bold = $true
    $customersWS.Columns.AutoFit() | Out-Null
    
    $workbook.SaveAs("$testDataPath\multiple-sheets.xlsx")
    $workbook.Close()

    # 4. Large dataset for performance testing
    Write-Host "Creating: large-dataset.xlsx (1000 rows for performance testing)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "LargeData"
    
    # Headers
    $worksheet.Cells.Item(1, 1) = "ID"
    $worksheet.Cells.Item(1, 2) = "Name"
    $worksheet.Cells.Item(1, 3) = "Email"
    $worksheet.Cells.Item(1, 4) = "Department"
    $worksheet.Cells.Item(1, 5) = "Salary"
    $worksheet.Cells.Item(1, 6) = "StartDate"
    
    $worksheet.Range("A1:F1").Font.Bold = $true
    
    # Generate data
    $departments = @("Sales", "Marketing", "IT", "HR", "Finance")
    $random = New-Object System.Random
    
    for ($i = 2; $i -le 1001; $i++) {
        $id = $i - 1
        $worksheet.Cells.Item($i, 1) = $id
        $worksheet.Cells.Item($i, 2) = "User$id"
        $worksheet.Cells.Item($i, 3) = "user$id@example.com"
        $worksheet.Cells.Item($i, 4) = $departments[$random.Next(5)]
        $worksheet.Cells.Item($i, 5) = $random.Next(30000, 120000)
        $worksheet.Cells.Item($i, 6) = (Get-Date).AddDays(-$random.Next(3650))
    }
    
    $worksheet.Columns.AutoFit() | Out-Null
    
    $workbook.SaveAs("$testDataPath\large-dataset.xlsx")
    $workbook.Close()

    # 5. Empty worksheet
    Write-Host "Creating: empty.xlsx (empty worksheet for edge case testing)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "Empty"
    
    $workbook.SaveAs("$testDataPath\empty.xlsx")
    $workbook.Close()

    # 6. Complex data types
    Write-Host "Creating: complex-data.xlsx (complex data types for robust testing)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    $worksheet.Name = "ComplexData"
    
    # Headers
    $worksheet.Cells.Item(1, 1) = "Name"
    $worksheet.Cells.Item(1, 2) = "Numbers"
    $worksheet.Cells.Item(1, 3) = "Date"
    $worksheet.Cells.Item(1, 4) = "Boolean"
    $worksheet.Cells.Item(1, 5) = "Special"
    
    $worksheet.Range("A1:E1").Font.Bold = $true
    
    # Complex data
    $worksheet.Cells.Item(2, 1) = "Complex Item 1"
    $worksheet.Cells.Item(2, 2) = 12345
    $worksheet.Cells.Item(2, 3) = Get-Date
    $worksheet.Cells.Item(2, 4) = "TRUE"
    $worksheet.Cells.Item(2, 5) = "Text with, commas and ""quotes"""
    
    $worksheet.Cells.Item(3, 1) = "Complex Item 2"
    $worksheet.Cells.Item(3, 2) = 67890
    $worksheet.Cells.Item(3, 3) = (Get-Date).AddDays(-30)
    $worksheet.Cells.Item(3, 4) = "FALSE"
    $worksheet.Cells.Item(3, 5) = "More special chars: !@#$%^&*()"
    
    $worksheet.Columns.AutoFit() | Out-Null
    
    $workbook.SaveAs("$testDataPath\complex-data.xlsx")
    $workbook.Close()

    # 7. Macro-enabled format (.xlsm)
    Write-Host "Creating: test.xlsm (macro-enabled format)" -ForegroundColor Yellow
    
    $workbook = $excel.Workbooks.Add()
    $worksheet = $workbook.Worksheets.Item(1)
    
    # Simple data
    $worksheet.Cells.Item(1, 1) = "Name"
    $worksheet.Cells.Item(1, 2) = "Value"
    $worksheet.Cells.Item(2, 1) = "Test1"
    $worksheet.Cells.Item(2, 2) = 100
    $worksheet.Cells.Item(3, 1) = "Test2"
    $worksheet.Cells.Item(3, 2) = 200
    
    $worksheet.Range("A1:B1").Font.Bold = $true
    $worksheet.Columns.AutoFit() | Out-Null
    
    # Save as macro-enabled format
    $workbook.SaveAs("$testDataPath\test.xlsm", 52) # xlOpenXMLWorkbookMacroEnabled
    $workbook.Close()

    Write-Host "`nTest data creation completed!" -ForegroundColor Green
    Write-Host "Files created in: $testDataPath" -ForegroundColor Cyan

    # List all created files
    Write-Host "`nCreated test files:" -ForegroundColor Cyan
    Get-ChildItem $testDataPath | ForEach-Object {
        Write-Host "  - $($_.Name)" -ForegroundColor White
    }
}
catch {
    Write-Error "Error creating test data: $($_.Exception.Message)"
    exit 1
}
finally {
    # Clean up Excel COM object
    if ($excel) {
        try {
            $excel.Quit()
            [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        }
        catch {
            Write-Warning "Could not properly close Excel application"
        }
    }
    
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}