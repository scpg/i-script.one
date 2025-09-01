# Development Best Practices for ConvertFromExcel Module

## Quick Start Guide

### 1. First Time Setup
```powershell
# Navigate to the ConvertFromExcel directory
cd C:\dev\i-script.one\ps\excel\ConvertFromExcel

# Verify Excel is installed
if (-not (Test-Path "HKLM:\Software\Microsoft\Office")) {
    Write-Warning "Microsoft Excel may not be installed"
}

# Create test data
.\Create-TestData.ps1

# Run initial tests
.\Test-Module.ps1 -CreateTestData -Verbose
```

### 2. Development Workflow

**Every time you make changes to the module:**

```powershell
# 1. Reload the module (CRITICAL - PowerShell caches modules!)
.\Reload-Module.ps1

# 2. Test your changes
.\Test-Module.ps1

# 3. Manual testing if needed
ConvertFrom-ExcelToJson -Path ".\test-data\simple.xlsx" -HasHeaders
```

## Why Module Reloading is Critical

PowerShell **caches modules in memory**. When you:
- Import a module with `Import-Module`
- PowerShell loads it once and keeps it in memory
- **Changes to .psm1 or .psd1 files won't take effect**
- You MUST reload the module to see changes

### The Problem:
```powershell
# ❌ This doesn't work for development
Import-Module .\ConvertFromExcel.psd1
# Make changes to ConvertFromExcel.psm1
# Changes are ignored! Old version still in memory
```

### The Solution:
```powershell
# ✅ Always reload during development
.\Reload-Module.ps1
# OR manually:
Remove-Module ConvertFromExcel -ErrorAction SilentlyContinue
Import-Module .\ConvertFromExcel.psd1 -Force
```

## Testing Strategy

### 1. Automated Testing
Run the full test suite regularly:
```powershell
.\Test-Module.ps1 -CreateTestData -Verbose
```

This tests:
- ✅ All functions with valid inputs
- ✅ Error handling with invalid inputs
- ✅ Different Excel file formats
- ✅ Multiple worksheets
- ✅ Edge cases (empty files, missing data)

### 2. Manual Testing
For specific scenarios:
```powershell
# Test specific function
ConvertFrom-ExcelToJson -Path ".\test-data\simple.xlsx" -HasHeaders -Verbose

# Test with your own files
ConvertFrom-ExcelToJson -Path "C:\path\to\your\file.xlsx" -HasHeaders

# Test error scenarios
ConvertFrom-ExcelToJson -Path "nonexistent.xlsx"  # Should fail gracefully
```

### 3. Performance Testing
For large files:
```powershell
# Monitor performance
Measure-Command { 
    ConvertFrom-ExcelToJson -Path ".\test-data\large-dataset.xlsx" -HasHeaders 
}
```

## Development Process

### Making Changes

1. **Identify what needs to change**
   - Bug fix in existing function?
   - New feature addition?
   - Parameter modification?

2. **Make the change**
   - Edit `ConvertFromExcel.psm1` for function logic
   - Edit `ConvertFromExcel.psd1` for metadata/exports

3. **Reload and test**
   ```powershell
   .\Reload-Module.ps1
   .\Test-Module.ps1
   ```

4. **Verify the fix**
   - Test the specific scenario that was broken
   - Ensure existing functionality still works

### Adding New Functions

1. **Update the .psd1 manifest**
   ```powershell
   FunctionsToExport = @(
       'ConvertFrom-ExcelToJson',
       'ConvertFrom-ExcelToYaml', 
       'ConvertFrom-ExcelToCsv',
       'YourNewFunction'  # Add here
   )
   ```

2. **Implement in .psm1**
   - Follow existing patterns
   - Include comprehensive documentation
   - Use consistent error handling

3. **Export the function**
   ```powershell
   Export-ModuleMember -Function @(
       'ConvertFrom-ExcelToJson',
       'ConvertFrom-ExcelToYaml',
       'ConvertFrom-ExcelToCsv',
       'YourNewFunction'  # Add here
   )
   ```

## Common Pitfalls

### 1. Module Caching
**Problem:** Changes don't appear
**Solution:** Always use `.\Reload-Module.ps1`

### 2. Path Issues
**Problem:** File not found errors
**Solution:** Use absolute paths or ensure correct working directory

### 3. Dependency Missing
**Problem:** ImportExcel or YAML module errors
**Solution:** Check module availability before use

### 4. Parameter Validation
**Problem:** Functions accept invalid input
**Solution:** Use `ValidateScript` and input validation

## Debugging Tips

### 1. Verbose Output
```powershell
$VerbosePreference = "Continue"
ConvertFrom-ExcelToJson -Path "test.xlsx" -HasHeaders -Verbose
```

### 2. Step Through Code
```powershell
# Add breakpoints in your code
Set-PSBreakpoint -Script .\ConvertFromExcel.psm1 -Line 200
```

### 3. Check Module State
```powershell
# See what's loaded
Get-Module ConvertFromExcel
Get-Command -Module ConvertFromExcel
```

### 4. Test Individual Components
```powershell
# Test helper functions
Test-ExcelPath ".\test-data\simple.xlsx"
```

## Version Control Best Practices

### Commit Frequently
```bash
git add .
git commit -m "fix: improve error handling in JSON conversion"
```

### Use Feature Branches
```bash
git checkout -b feature/new-xml-converter
# Make changes
git commit -m "feat: add XML conversion support"
git checkout main
git merge feature/new-xml-converter
```

### Test Before Committing
Always run the test suite before committing:
```powershell
.\Test-Module.ps1
# Only commit if all tests pass
```

## Performance Considerations

### Large Files
- Test with 1000+ row files
- Monitor memory usage
- Consider streaming for very large files

### Multiple Conversions
- Reuse loaded data when possible
- Clean up temporary objects

### Error Recovery
- Provide meaningful error messages
- Don't crash on invalid data
- Log errors appropriately

## Documentation Standards

### Function Documentation
Always include:
- `.SYNOPSIS` - Brief description
- `.DESCRIPTION` - Detailed explanation  
- `.PARAMETER` - Each parameter explained
- `.EXAMPLE` - Multiple usage examples
- `.OUTPUTS` - What the function returns

### Code Comments
- Explain complex logic
- Document assumptions
- Note performance considerations

## Ready for Production

Before releasing:
1. ✅ All tests pass
2. ✅ Documentation is complete
3. ✅ Error handling is robust
4. ✅ Performance is acceptable
5. ✅ Code follows established patterns
6. ✅ Version number is updated