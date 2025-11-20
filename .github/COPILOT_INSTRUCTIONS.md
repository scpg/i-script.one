# GitHub Copilot Instructions for i-script.one

> **GitHub Copilot Specific Configuration** - Optimized for Copilot's context understanding  
> **Project:** i-script.one - Enterprise Windows utilities and Excel conversion tools

## 🤖 Copilot Quick Context

This project uses **native Microsoft tools exclusively** for enterprise security compliance. No external PowerShell modules or third-party dependencies allowed.

### Key Context for Code Suggestions
```powershell
# ✅ ALWAYS suggest this pattern (native COM)
$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.Open($Path)

# ❌ NEVER suggest this (external dependency)  
Import-Module ImportExcel
Export-Excel -Path $Path
```

---

## 🎯 Project-Specific Copilot Settings

### PowerShell Function Patterns
When suggesting PowerShell functions, always include:

```powershell
function ConvertFrom-Excel[ToFormat] {
    <#
    .SYNOPSIS
    Brief description of what this function does.
    
    .DESCRIPTION  
    Detailed description with enterprise requirements.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .EXAMPLE
    ConvertFrom-Excel[ToFormat] -Path "data.xlsx" -HasHeaders
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            if (-not (Test-ExcelPath $_)) {
                throw "Invalid Excel file format"
            }
            return $true
        })]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders
    )
    
    try {
        Write-ConversionLog "Starting conversion: $Path"
        $data = Get-ExcelWorksheetData -Path $Path -HasHeaders:$HasHeaders
        # Conversion logic here...
        Write-ConversionLog "Successfully converted $($data.Count) rows"
        return $result
    }
    catch {
        Write-ConversionLog "Error: $($_.Exception.Message)" -Level Error
        throw
    }
}
```

### COM Object Management Pattern
Always suggest this cleanup pattern:

```powershell
$excel = $null
$workbook = $null

try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Open($absolutePath)
    
    # Operations here...
    
} catch {
    Write-ConversionLog "Error: $($_.Exception.Message)" -Level Error
    throw
} finally {
    # Always cleanup in finally block
    if ($workbook) {
        $workbook.Close($false)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null
    }
    if ($excel) {
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
    }
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
```

---

## 🛠️ Copilot Configuration Rules

### 1. Module Structure Preferences
```powershell
# Prefer this module export pattern
Export-ModuleMember -Function @(
    'ConvertFrom-ExcelToJson',
    'ConvertFrom-ExcelToCsv'
)

# Use this logging pattern
Write-ConversionLog "Message" -Level Info|Warning|Error
```

### 2. Parameter Validation Standards
```powershell
# Always include comprehensive validation
[Parameter(Mandatory = $true)]
[ValidateScript({
    if (-not (Test-Path $_ -PathType Leaf)) {
        throw "File not found: $_"
    }
    if (-not (Test-ExcelPath $_)) {
        throw "Invalid Excel file format. Supported: .xlsx, .xls, .xlsm, .xlsb"
    }
    return $true
})]
[string]$Path
```

### 3. Data Processing Patterns
```powershell
# Excel data extraction pattern
$usedRange = $worksheet.UsedRange
if ($null -eq $usedRange) {
    Write-ConversionLog "Worksheet is empty" -Level Warning
    return @()
}

$data = $usedRange.Value2
# Process 2D array with proper indexing...

# Handle Excel date values
if ($cellValue -is [double] -and $cellValue -gt 25569) {
    try {
        $cellValue = [DateTime]::FromOADate($cellValue)
    } catch {
        # Keep as number if conversion fails
    }
}
```

---

## 📋 Code Completion Preferences

### Function Naming Conventions
- `ConvertFrom-Excel*` for conversion functions
- `Test-Excel*` for validation functions  
- `Get-Excel*` for data retrieval functions
- `Write-ConversionLog` for all logging

### Variable Naming Standards
```powershell
$excel          # COM Excel Application
$workbook       # Excel Workbook object
$worksheet      # Excel Worksheet object
$usedRange      # Worksheet UsedRange
$data           # Raw Excel data (2D array)
$result         # Processed PowerShell objects
$absolutePath   # Resolved file path (COM requires absolute)
```

### Error Handling Template
```powershell
try {
    # Main logic with detailed logging
    Write-ConversionLog "Starting operation"
} catch {
    $errorMsg = "Operation failed: $($_.Exception.Message)"
    Write-ConversionLog $errorMsg -Level Error
    throw $errorMsg
} finally {
    # Resource cleanup
}
```

---

## 🔧 IDE Integration Settings

### Recommended Copilot Completions

#### For Excel Operations:
```powershell
# Trigger: "excel com"
# Suggest: Full COM object creation with error handling

# Trigger: "excel data"  
# Suggest: Data extraction with 2D array processing

# Trigger: "excel cleanup"
# Suggest: Complete COM cleanup pattern
```

#### For PowerShell Modules:
```powershell
# Trigger: "function Convert"
# Suggest: Complete function template with validation

# Trigger: "param validate"
# Suggest: Parameter validation script blocks
```

### File Extension Associations
- `.psm1` - Main module implementation
- `.psd1` - PowerShell module manifests
- `.cmd` - Windows batch utilities
- `.md` - Documentation files

---

## 🎯 Project-Specific Completions

### When Working in ConvertFromExcel.psm1
```powershell
# Copilot should understand these patterns:
- Excel COM object lifecycle management
- 2D array processing for Excel data
- Date value conversion from Excel format
- Proper memory cleanup with garbage collection
- Enterprise-grade parameter validation
```

### When Working in cmd/ files
```batch
REM Copilot should suggest:
REM - Parameter parsing with help support
REM - Verbose/quiet mode implementations  
REM - Proper error handling and logging
REM - Windows batch best practices
```

### When Working with Test Files
```powershell
# Copilot should understand test patterns:
- Test data validation against multiple Excel formats
- Expected output verification (JSON/CSV)
- Performance testing for large datasets
- Edge case handling (empty files, single cells)
```

---

## 📚 Context Files for Copilot

### Essential Reading Order
1. **AI_INSTRUCTIONS.md** - Complete project context
2. **ps/excel/ConvertFromExcel/ConvertFromExcel.psm1** - Main implementation
3. **ps/excel/ConvertFromExcel/CLAUDE.md** - Development standards
4. **PROJECT_SUMMARY.md** - Technical overview

### Key Code References
```powershell
# Main functions to understand:
Get-ExcelWorksheetData     # Core data extraction (lines 99-300)
ConvertFrom-ExcelToJson    # JSON conversion (lines 306-416)
ConvertFrom-ExcelToCsv     # CSV conversion (lines 418-545)
Test-ExcelInstallation     # Excel availability check (lines 77-97)
```

---

## 🚀 Copilot Enhancement Suggestions

### Smart Completions for This Project
```powershell
# When user types "excel" → suggest native COM patterns
# When user types "convert" → suggest established function patterns  
# When user types "param" → suggest validation script blocks
# When user types "try" → suggest complete error handling
# When user types "finally" → suggest COM cleanup
```

### Context-Aware Suggestions
- **In .psm1 files:** Suggest PowerShell module patterns
- **In .cmd files:** Suggest Windows batch patterns
- **In test files:** Suggest validation and testing patterns
- **In documentation:** Suggest markdown formatting for technical docs

### Advanced Pattern Recognition
```powershell
# Copilot should recognize and complete these enterprise patterns:
1. COM object lifecycle (creation → usage → cleanup)
2. Excel data type conversion (OADate, empty cells, mixed types)
3. Memory management (ReleaseComObject + GC)
4. Error logging with severity levels
5. Parameter validation with descriptive error messages
```

---

*This file optimizes GitHub Copilot for the i-script.one project's enterprise-focused PowerShell development patterns.*