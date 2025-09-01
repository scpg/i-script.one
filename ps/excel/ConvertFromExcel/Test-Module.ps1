<#
.SYNOPSIS
Comprehensive test script for the ConvertFromExcel module.

.DESCRIPTION
This script performs automated testing of all ConvertFromExcel module functions
with various scenarios including success cases, error cases, and edge cases.

.NOTES
Author: scpg
Date: 2025-09-01
Requires: ConvertFromExcel module, ImportExcel module, powershell-yaml module
#>

param(
    [switch]$CreateTestData,
    [switch]$CleanupAfter,
    [switch]$Verbose
)

# Set up verbose output if requested
if ($Verbose) {
    $VerbosePreference = "Continue"
}

# Color coding for test results
function Write-TestResult {
    param(
        [string]$TestName,
        [string]$Result,
        [string]$Details = ""
    )
    
    $color = switch ($Result) {
        "PASS" { "Green" }
        "FAIL" { "Red" }
        "SKIP" { "Yellow" }
        "INFO" { "Cyan" }
        default { "White" }
    }
    
    Write-Host "[$Result] $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "    $Details" -ForegroundColor Gray
    }
}

# Test counter
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:TestsSkipped = 0

function Test-Function {
    param(
        [string]$TestName,
        [scriptblock]$TestScript,
        [switch]$ShouldFail
    )
    
    try {
        $result = & $TestScript
        
        if ($ShouldFail) {
            Write-TestResult $TestName "FAIL" "Expected error but test passed"
            $script:TestsFailed++
        } else {
            Write-TestResult $TestName "PASS" "Returned: $($result -join ', ')"
            $script:TestsPassed++
        }
    }
    catch {
        if ($ShouldFail) {
            Write-TestResult $TestName "PASS" "Expected error: $($_.Exception.Message)"
            $script:TestsPassed++
        } else {
            Write-TestResult $TestName "FAIL" "Unexpected error: $($_.Exception.Message)"
            $script:TestsFailed++
        }
    }
}

Write-Host "=== ConvertFromExcel Module Test Suite ===" -ForegroundColor Cyan
Write-Host "Start Time: $(Get-Date)" -ForegroundColor Gray

# Setup paths
$ModulePath = Join-Path $PSScriptRoot "ConvertFromExcel.psd1"
$TestDataPath = Join-Path $PSScriptRoot "test-data"
$TestOutputPath = Join-Path $PSScriptRoot "test-output"

# Ensure test output directory exists
if (-not (Test-Path $TestOutputPath)) {
    New-Item -Path $TestOutputPath -ItemType Directory | Out-Null
}

# Create test data if requested or if it doesn't exist
if ($CreateTestData -or -not (Test-Path $TestDataPath)) {
    Write-TestResult "Setup" "INFO" "Creating test data..."
    & (Join-Path $PSScriptRoot "Create-TestData.ps1")
}

# Check prerequisites
Write-Host "`n=== Prerequisites Check ===" -ForegroundColor Yellow

if (Get-Module -ListAvailable -Name ImportExcel) {
    Write-TestResult "ImportExcel Module" "PASS" "Module available"
} else {
    Write-TestResult "ImportExcel Module" "FAIL" "Module not installed - run: Install-Module ImportExcel"
    exit 1
}

if (Get-Module -ListAvailable -Name powershell-yaml) {
    Write-TestResult "PowerShell-Yaml Module" "PASS" "Module available"
    $yamlAvailable = $true
} elseif (Get-Module -ListAvailable -Name PSYaml) {
    Write-TestResult "PSYaml Module" "PASS" "Module available"
    $yamlAvailable = $true
} else {
    Write-TestResult "YAML Module" "SKIP" "No YAML module installed - YAML tests will be skipped"
    $yamlAvailable = $false
}

# Import the module
Write-Host "`n=== Module Import ===" -ForegroundColor Yellow

try {
    Remove-Module ConvertFromExcel -ErrorAction SilentlyContinue
    Import-Module $ModulePath -Force
    Write-TestResult "Module Import" "PASS" "ConvertFromExcel module loaded successfully"
    
    $exportedFunctions = Get-Command -Module ConvertFromExcel
    Write-TestResult "Exported Functions" "PASS" "Found $($exportedFunctions.Count) functions: $($exportedFunctions.Name -join ', ')"
}
catch {
    Write-TestResult "Module Import" "FAIL" $_.Exception.Message
    exit 1
}

# Test files
$testFiles = @{
    "simple.xlsx" = "Simple data with headers"
    "no-headers.xlsx" = "Data without headers"
    "multiple-sheets.xlsx" = "Multiple worksheets"
    "empty.xlsx" = "Empty worksheet"
}

Write-Host "`n=== JSON Conversion Tests ===" -ForegroundColor Yellow

foreach ($file in $testFiles.Keys) {
    $filePath = Join-Path $TestDataPath $file
    
    if (Test-Path $filePath) {
        # Test basic JSON conversion (return string)
        Test-Function "JSON String: $file" {
            $result = ConvertFrom-ExcelToJson -Path $filePath -HasHeaders
            if ($result -and $result.Length -gt 0) {
                # Validate it's valid JSON
                $parsed = $result | ConvertFrom-Json
                return "Valid JSON with $($parsed.Count) items"
            } else {
                throw "Empty or null result"
            }
        }
        
        # Test JSON file output
        $outputFile = Join-Path $TestOutputPath "$([System.IO.Path]::GetFileNameWithoutExtension($file)).json"
        Test-Function "JSON File: $file" {
            $result = ConvertFrom-ExcelToJson -Path $filePath -OutputPath $outputFile -HasHeaders
            if (Test-Path $outputFile) {
                $content = Get-Content $outputFile -Raw | ConvertFrom-Json
                return "File created with $($content.Count) items"
            } else {
                throw "Output file not created"
            }
        }
    } else {
        Write-TestResult "JSON Test: $file" "SKIP" "Test file not found"
        $script:TestsSkipped++
    }
}

Write-Host "`n=== CSV Conversion Tests ===" -ForegroundColor Yellow

foreach ($file in $testFiles.Keys) {
    $filePath = Join-Path $TestDataPath $file
    
    if (Test-Path $filePath) {
        # Test CSV conversion
        $outputFile = Join-Path $TestOutputPath "$([System.IO.Path]::GetFileNameWithoutExtension($file)).csv"
        Test-Function "CSV File: $file" {
            $result = ConvertFrom-ExcelToCsv -Path $filePath -OutputPath $outputFile -HasHeaders -NoTypeInformation
            if (Test-Path $outputFile) {
                $lines = Get-Content $outputFile
                return "File created with $($lines.Count) lines"
            } else {
                throw "Output file not created"
            }
        }
    } else {
        Write-TestResult "CSV Test: $file" "SKIP" "Test file not found"
        $script:TestsSkipped++
    }
}

if ($yamlAvailable) {
    Write-Host "`n=== YAML Conversion Tests ===" -ForegroundColor Yellow
    
    foreach ($file in $testFiles.Keys) {
        $filePath = Join-Path $TestDataPath $file
        
        if (Test-Path $filePath) {
            # Test YAML conversion
            $outputFile = Join-Path $TestOutputPath "$([System.IO.Path]::GetFileNameWithoutExtension($file)).yaml"
            Test-Function "YAML File: $file" {
                $result = ConvertFrom-ExcelToYaml -Path $filePath -OutputPath $outputFile -HasHeaders
                if (Test-Path $outputFile) {
                    $content = Get-Content $outputFile -Raw
                    return "File created ($(($content -split "`n").Count) lines)"
                } else {
                    throw "Output file not created"
                }
            }
        } else {
            Write-TestResult "YAML Test: $file" "SKIP" "Test file not found"
            $script:TestsSkipped++
        }
    }
} else {
    Write-Host "`n=== YAML Conversion Tests ===" -ForegroundColor Yellow
    Write-TestResult "YAML Tests" "SKIP" "YAML module not available"
    $script:TestsSkipped += 4
}

Write-Host "`n=== Error Handling Tests ===" -ForegroundColor Yellow

# Test with non-existent file
Test-Function "Non-existent File" {
    ConvertFrom-ExcelToJson -Path "C:\NonExistent\file.xlsx"
} -ShouldFail

# Test with invalid file extension
$invalidFile = Join-Path $TestOutputPath "test.txt"
"Invalid content" | Out-File $invalidFile
Test-Function "Invalid File Extension" {
    ConvertFrom-ExcelToJson -Path $invalidFile
} -ShouldFail

# Test with non-existent worksheet
$simpleFile = Join-Path $TestDataPath "simple.xlsx"
if (Test-Path $simpleFile) {
    Test-Function "Non-existent Worksheet" {
        ConvertFrom-ExcelToJson -Path $simpleFile -WorksheetName "NonExistentSheet"
    } -ShouldFail
}

Write-Host "`n=== Multiple Worksheet Tests ===" -ForegroundColor Yellow

$multiSheetFile = Join-Path $TestDataPath "multiple-sheets.xlsx"
if (Test-Path $multiSheetFile) {
    $worksheets = @("Sales", "Inventory", "Customers")
    
    foreach ($worksheet in $worksheets) {
        Test-Function "Specific Worksheet: $worksheet" {
            $result = ConvertFrom-ExcelToJson -Path $multiSheetFile -WorksheetName $worksheet -HasHeaders
            $parsed = $result | ConvertFrom-Json
            return "Worksheet '$worksheet' with $($parsed.Count) items"
        }
    }
}

# Cleanup test files if requested
if ($CleanupAfter) {
    Write-Host "`n=== Cleanup ===" -ForegroundColor Yellow
    try {
        Remove-Item $TestOutputPath -Recurse -Force -ErrorAction Stop
        Write-TestResult "Cleanup" "PASS" "Test output files removed"
    }
    catch {
        Write-TestResult "Cleanup" "FAIL" $_.Exception.Message
    }
}

# Test Summary
Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Tests Passed: $script:TestsPassed" -ForegroundColor Green
Write-Host "Tests Failed: $script:TestsFailed" -ForegroundColor Red
Write-Host "Tests Skipped: $script:TestsSkipped" -ForegroundColor Yellow
Write-Host "Total Tests: $($script:TestsPassed + $script:TestsFailed + $script:TestsSkipped)"
Write-Host "End Time: $(Get-Date)" -ForegroundColor Gray

if ($script:TestsFailed -eq 0) {
    Write-Host "`n✅ All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Some tests failed. Review the output above." -ForegroundColor Red
    exit 1
}