# Testing Guide for ConvertFromExcel Module

## Prerequisites

### Required Modules
Before testing, install these PowerShell modules:

```powershell
# Required for Excel file operations
Install-Module ImportExcel -Scope CurrentUser

# Required for YAML conversion
Install-Module powershell-yaml -Scope CurrentUser

# Alternative YAML module
# Install-Module PSYaml -Scope CurrentUser
```

## Development Workflow

### 1. Module Reloading During Development

**IMPORTANT:** PowerShell caches modules, so you need to reload them after changes.

#### Option A: Force Reload Script
Use the provided `Reload-Module.ps1` script:
```powershell
.\Reload-Module.ps1
```

#### Option B: Manual Reload
```powershell
# Remove module from memory
Remove-Module ConvertFromExcel -ErrorAction SilentlyContinue

# Import fresh version
Import-Module .\ConvertFromExcel.psd1 -Force
```

### 2. Testing Process

1. **Make changes** to your module files
2. **Reload the module** (using above methods)
3. **Run your tests** to verify functionality
4. **Repeat** as needed

## Manual Testing

### Basic Function Testing
```powershell
# 1. Import the module
Import-Module .\ConvertFromExcel.psd1 -Force

# 2. Test JSON conversion
ConvertFrom-ExcelToJson -Path ".\test-data.xlsx" -HasHeaders

# 3. Test YAML conversion
ConvertFrom-ExcelToYaml -Path ".\test-data.xlsx" -HasHeaders

# 4. Test CSV conversion
ConvertFrom-ExcelToCsv -Path ".\test-data.xlsx" -HasHeaders

# 5. Test file output
ConvertFrom-ExcelToJson -Path ".\test-data.xlsx" -OutputPath ".\output.json" -HasHeaders
```

### Error Testing
```powershell
# Test with non-existent file
ConvertFrom-ExcelToJson -Path ".\nonexistent.xlsx"

# Test with invalid file format
ConvertFrom-ExcelToJson -Path ".\test.txt"

# Test with specific worksheet
ConvertFrom-ExcelToJson -Path ".\test-data.xlsx" -WorksheetName "NonExistentSheet"
```

## Automated Testing with Test-Module.ps1

Run the comprehensive test script:
```powershell
.\Test-Module.ps1
```

This script will:
- Test all functions with valid inputs
- Test error conditions
- Verify output formats
- Check file creation
- Clean up test files

## Debugging Tips

### 1. Enable Verbose Output
```powershell
$VerbosePreference = "Continue"
ConvertFrom-ExcelToJson -Path ".\test-data.xlsx" -HasHeaders -Verbose
```

### 2. Check Module Loading
```powershell
# List loaded modules
Get-Module ConvertFromExcel

# Check exported functions
Get-Command -Module ConvertFromExcel
```

### 3. Test Individual Functions
```powershell
# Test helper functions directly (if exported)
Test-ExcelPath ".\test-data.xlsx"
```

## Common Issues and Solutions

### Issue: Module Not Updating
**Problem:** Changes to module code don't take effect
**Solution:** Always use `Import-Module -Force` or the reload script

### Issue: ImportExcel Module Missing
**Problem:** "ImportExcel module is required" error
**Solution:** `Install-Module ImportExcel -Scope CurrentUser`

### Issue: YAML Module Missing
**Problem:** YAML conversion fails
**Solution:** `Install-Module powershell-yaml -Scope CurrentUser`

### Issue: File Path Errors
**Problem:** File not found errors
**Solution:** Use full paths or ensure you're in the correct directory

## Best Practices for Development

### 1. Test-Driven Development
- Write tests before implementing new features
- Test both success and failure scenarios
- Test with different Excel file formats

### 2. Incremental Development
- Make small changes and test frequently
- Use version control to track working versions
- Keep backups of working code

### 3. Real-World Testing
- Test with actual Excel files from your use cases
- Test with large files to check performance
- Test with different Excel versions and formats

### 4. Documentation Testing
- Verify all examples in help documentation work
- Test parameter combinations shown in examples
- Ensure error messages are helpful

## Performance Testing

### Large File Testing
```powershell
# Test with larger Excel files
Measure-Command { 
    ConvertFrom-ExcelToJson -Path ".\large-file.xlsx" -HasHeaders 
}
```

### Memory Usage
```powershell
# Monitor memory usage during conversion
$before = (Get-Process -Id $PID).WorkingSet64
ConvertFrom-ExcelToJson -Path ".\test-data.xlsx" -HasHeaders
$after = (Get-Process -Id $PID).WorkingSet64
Write-Host "Memory used: $([math]::Round(($after - $before) / 1MB, 2)) MB"
```

## Test Data Organization

### Directory Structure
```
excel/
├── ConvertFromExcel.psd1
├── ConvertFromExcel.psm1
├── CLAUDE.md
├── TESTING.md
├── test-data/
│   ├── simple.xlsx          # Basic test data
│   ├── with-headers.xlsx    # Data with headers
│   ├── multiple-sheets.xlsx # Multiple worksheets
│   └── empty.xlsx          # Edge case testing
├── test-output/            # Generated test files
└── Test-Module.ps1         # Automated test script
```