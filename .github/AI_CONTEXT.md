# AI Context for GitHub Copilot & AI Tools

> **GitHub Integration File** - Optimized for GitHub Copilot, but compatible with all AI assistants  
> **Auto-loaded by:** GitHub Copilot, GitHub Actions, and other GitHub-integrated AI tools  
> **Project:** i-script.one - Enterprise Windows utilities and data conversion tools

## 🎯 Project Summary

**i-script.one** is an enterprise-ready collection of Windows utilities focused on:
- **Excel data conversion** using native Microsoft tools (zero dependencies)
- **Windows system management** and dependency analysis
- **Corporate environment compatibility** with security-first architecture

### Quick Context for AI
- **Language:** PowerShell 5.1+, Windows Batch
- **Platform:** Windows (COM objects, native tools only)
- **Architecture:** Enterprise-grade, zero third-party dependencies
- **Status:** Production-ready Excel module + system utilities

---

## 🏗️ Codebase Structure

```
Key Files & Their Purpose:
├── AI_INSTRUCTIONS.md          # 📖 Complete AI context (READ THIS FIRST)
├── ps/excel/ConvertFromExcel/  # 🎯 Main Excel conversion module
│   ├── ConvertFromExcel.psm1   # Core implementation (553 lines)
│   ├── ConvertFromExcel.psd1   # Module manifest
│   ├── CLAUDE.md              # Development guidelines
│   └── backlog/               # Task management
├── cmd/                       # Windows batch utilities
│   ├── analyze-dependencies.cmd # Runtime dependency analyzer  
│   └── *-managedSoftware.cmd  # Software management tools
└── CLAUDE.md                  # Root project guidelines
```

---

## 🔧 Core Technology Stack

### Excel Module Architecture
```powershell
# Native Microsoft Excel COM objects - Enterprise compatible
$excel = New-Object -ComObject Excel.Application
$workbook = $excel.Workbooks.Open($Path)
$data = $worksheet.UsedRange.Value2

# Zero external dependencies - Security compliant
ConvertFrom-ExcelToJson -Path "data.xlsx" -HasHeaders
ConvertFrom-ExcelToCsv -Path "data.xlsx" -Delimiter ";" -HasHeaders
```

### Key Implementation Patterns
- **COM Object Management:** Proper creation, usage, cleanup with garbage collection
- **Enterprise Validation:** File existence, format validation, Excel installation checks  
- **Memory Safety:** Try/finally blocks with `ReleaseComObject` calls
- **Data Type Handling:** Excel date conversion, empty cell processing, type preservation

---

## 📊 AI Assistant Guidelines

### When Suggesting Code Changes
1. **Follow native-only approach** - No ImportExcel, no external modules
2. **Use established patterns** - COM object cleanup, error handling, logging
3. **Maintain enterprise standards** - Parameter validation, comprehensive help
4. **Consider memory management** - Proper COM object disposal

### Code Style Enforcement
```powershell
# ✅ Correct Pattern
try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    # ... operations
} catch {
    Write-ConversionLog "Error: $($_.Exception.Message)" -Level Error
    throw
} finally {
    if ($workbook) { $workbook.Close($false) }
    if ($excel) { $excel.Quit() }
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
    [System.GC]::Collect()
}
```

### Security Requirements
- **Input validation:** Always validate file paths and parameters
- **COM safety:** Never leave COM objects hanging
- **Error handling:** Don't expose sensitive system information
- **Path security:** Use absolute paths for COM operations

---

## 🎯 Current Development Status

### Completed Features ✅
- Excel to JSON/CSV conversion with native tools
- Windows dependency analysis utilities  
- Comprehensive test suite (7 test scenarios)
- Enterprise-grade error handling and logging
- Memory management and COM object cleanup

### Active Enhancement Pipeline 🚧
Based on `ps/excel/ConvertFromExcel/backlog/tasks/`:
1. **Extended Type Handling** - Enhanced data type detection
2. **Table Format Output** - Structured table export options
3. **Worksheet Pattern Matching** - Advanced worksheet selection

### Branch Information
- **Main branch:** `main`
- **Current feature branch:** `feature/excel-converter`
- **Last major commit:** Refactor to native Microsoft tools for enterprise compatibility

---

## 🔍 Key Code Locations

### Excel Module Core (`ps/excel/ConvertFromExcel/ConvertFromExcel.psm1`)
```powershell
# Lines 26-45: Test-ExcelPath - File validation
# Lines 77-97: Test-ExcelInstallation - Excel availability check  
# Lines 99-300: Get-ExcelWorksheetData - Core data extraction
# Lines 306-416: ConvertFrom-ExcelToJson - JSON conversion
# Lines 418-545: ConvertFrom-ExcelToCsv - CSV conversion
```

### System Utilities (`cmd/`)
- **`analyze-dependencies.cmd`** - Lines 94-101: PowerShell integration for package filtering
- **Software management tools** - Winget-based system management utilities

### Test Infrastructure
- **Test data:** `ps/excel/ConvertFromExcel/test-data/` (7 Excel files)
- **Expected outputs:** `ps/excel/ConvertFromExcel/test-output/` (JSON/CSV results)

---

## 🚀 Quick AI Integration Commands

### For GitHub Copilot
```powershell
# Navigate to main module
Set-Location ps/excel/ConvertFromExcel

# Import and test module
Import-Module .\ConvertFromExcel.psd1 -Force
ConvertFrom-ExcelToJson -Path "test-data/simple.xlsx" -HasHeaders

# Run tests
.\Test-Module.ps1
```

### For Code Analysis
```bash
# Key files to understand codebase
1. Read: AI_INSTRUCTIONS.md (complete context)
2. Read: ps/excel/ConvertFromExcel/ConvertFromExcel.psm1 (main implementation)  
3. Read: ps/excel/ConvertFromExcel/CLAUDE.md (development standards)
4. Check: ps/excel/ConvertFromExcel/backlog/tasks/ (active work)
```

---

## 🎨 Code Generation Guidelines

### When Writing PowerShell Functions
```powershell
function New-ExcelFunction {
    <#
    .SYNOPSIS
    Brief description of what this function does.
    
    .DESCRIPTION  
    Detailed description with requirements and behavior.
    
    .PARAMETER Path
    Description of Path parameter with validation requirements.
    
    .EXAMPLE
    New-ExcelFunction -Path "C:\data\file.xlsx" -HasHeaders
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
    
    # Implementation with proper error handling...
}
```

### When Modifying Existing Code
1. **Preserve existing patterns** - Don't break established conventions
2. **Update module version** - Increment in .psd1 if adding functionality
3. **Add comprehensive tests** - Use test-data files for validation
4. **Update documentation** - Help text, examples, and comments

---

## 📋 Testing Requirements

### Test Scenarios to Cover
- **All Excel formats:** .xlsx, .xls, .xlsm, .xlsb
- **Edge cases:** Empty files, single cells, no headers
- **Data types:** Dates, numbers, text, mixed data
- **Large datasets:** Performance and memory usage
- **Error conditions:** Missing files, invalid formats

### Expected Behavior
```powershell
# Test data validation
Get-ChildItem "test-data/*.xlsx" | ForEach-Object {
    $result = ConvertFrom-ExcelToJson -Path $_.FullName -HasHeaders
    # Verify $result is valid JSON
    $parsed = $result | ConvertFrom-Json
    Write-Host "✅ $($_.Name): $($parsed.Count) records processed"
}
```

---

## 🎯 AI-Specific Notes

### For GitHub Copilot
- This project prioritizes **enterprise compatibility** over convenience
- Always suggest **native Microsoft tools** instead of third-party modules
- Focus on **memory management** and **COM object cleanup**
- Maintain **comprehensive parameter validation**

### For ChatGPT/Claude/Gemini  
- Read `AI_INSTRUCTIONS.md` for complete project context
- Follow established error handling and logging patterns
- Consider enterprise security requirements in suggestions
- Test suggestions against existing test data files

### Common Enhancement Areas
1. **Performance optimization** - Large Excel file handling
2. **Format expansion** - Additional output formats beyond JSON/CSV
3. **Batch processing** - Multiple file conversion workflows  
4. **Advanced filtering** - Worksheet selection and data filtering

---

## 📚 Additional Resources

- **Complete AI Instructions:** [AI_INSTRUCTIONS.md](../AI_INSTRUCTIONS.md)
- **Module Guidelines:** [ps/excel/ConvertFromExcel/CLAUDE.md](../ps/excel/ConvertFromExcel/CLAUDE.md)  
- **Task Management:** [ps/excel/ConvertFromExcel/backlog/](../ps/excel/ConvertFromExcel/backlog/)
- **Test Data:** [ps/excel/ConvertFromExcel/test-data/](../ps/excel/ConvertFromExcel/test-data/)

---

*This file provides GitHub-optimized AI context. For complete project details, see [AI_INSTRUCTIONS.md](../AI_INSTRUCTIONS.md).*