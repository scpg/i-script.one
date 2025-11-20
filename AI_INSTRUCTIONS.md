# AI Assistant Instructions for i-script.one

> **Universal AI Context File** - Compatible with Claude, ChatGPT, Gemini, and other AI tools  
> **Version:** 1.0.0 | **Last Updated:** 2025-11-20  
> **Project:** i-script.one - Windows scripting and data conversion utilities

## 🤖 How to Use This File

**For AI Assistants:**
- Read this file completely before starting any work
- Follow the project standards and conventions outlined here
- Refer to the [Project Architecture](#project-architecture) section for understanding the codebase
- Use the [Code Analysis](#code-analysis-findings) section for context about existing implementations

**For Humans:**
- Share this file with any AI tool working on this project
- Keep this file updated when project structure or standards change
- Use this as onboarding material for new contributors

---

## 📋 Project Overview

**i-script.one** is a collection of enterprise-ready PowerShell and Windows utilities focused on:
- **Excel data conversion** (JSON/CSV) using native Microsoft tools
- **Windows system management** (dependency analysis, software management)
- **Enterprise compatibility** (zero third-party dependencies)

### Project Metadata
- **Author:** scpg
- **License:** MIT License
- **Platform:** Windows (PowerShell 5.1+)
- **Repository:** https://github.com/scpg/i-script.one
- **Main Branch:** main
- **Current Feature Branch:** feature/excel-converter

---

## 🏗️ Project Architecture

### Directory Structure
```
i-script.one/
├── AI_INSTRUCTIONS.md          # This file - Universal AI context
├── README.md                   # Project overview
├── LICENSE                     # MIT License
├── CLAUDE.md                   # Claude-specific development guidelines
├── cmd/                        # Windows batch utilities
│   ├── analyze-dependencies.cmd    # Runtime dependency analyzer
│   ├── list-managedSoftware.cmd    # Software inventory
│   ├── remove-managedSoftware.cmd  # Software removal
│   └── update-managedSoftware.cmd  # Software updates
├── ps/                         # PowerShell modules and scripts
│   ├── excel/                  # Excel conversion tools
│   │   └── ConvertFromExcel/   # Main Excel conversion module
│   │       ├── ConvertFromExcel.psd1  # Module manifest
│   │       ├── ConvertFromExcel.psm1  # Module implementation
│   │       ├── CLAUDE.md       # Module-specific guidelines
│   │       ├── DEPENDENCY-ANALYSIS.md # Dependency evaluation
│   │       ├── DEVELOPMENT.md  # Development documentation
│   │       ├── TESTING.md      # Testing guidelines
│   │       ├── backlog/        # Task management (Backlog.md CLI)
│   │       ├── test-data/      # Excel test files
│   │       └── test-output/    # Generated test outputs
│   └── get-ProfilesTrace.ps1   # PowerShell profile tracer
└── bash/                       # Future: Bash utilities
```

### Core Components

#### 1. Excel Conversion Module (`ps/excel/ConvertFromExcel/`)
**Purpose:** Convert Excel files to JSON/CSV using only native Microsoft tools

**Key Functions:**
- `ConvertFrom-ExcelToJson` - Excel → JSON conversion
- `ConvertFrom-ExcelToCsv` - Excel → CSV conversion

**Architecture Principles:**
- **Enterprise-first:** Zero third-party dependencies
- **Native Microsoft tools:** Excel COM objects only
- **Robust error handling:** Comprehensive validation and cleanup
- **Memory management:** Proper COM object disposal
- **Format support:** .xlsx, .xls, .xlsm, .xlsb

#### 2. Windows System Utilities (`cmd/`)
**Purpose:** Windows system management and dependency analysis

**Key Tools:**
- **Dependency Analyzer:** Identifies runtime dependencies (VCRedist, .NET, DirectX)
- **Software Manager:** List/update/remove software via winget
- **Security-focused:** Analysis only, manual removal commands

---

## 🔍 Code Analysis Findings

### Excel Module Implementation Analysis

#### ✅ Strengths Identified
1. **Enterprise Architecture:**
   - Uses native Excel COM objects exclusively
   - No ImportExcel or external module dependencies
   - Proper COM object cleanup with garbage collection
   - Memory management best practices

2. **Robust Data Handling:**
   - Supports all Excel formats (.xlsx, .xls, .xlsm, .xlsb)
   - Excel date value conversion (`FromOADate`)
   - Header detection and column naming
   - Empty worksheet handling

3. **Professional Code Quality:**
   - Comprehensive parameter validation
   - Detailed error messages with context
   - Consistent logging with `Write-ConversionLog`
   - Help documentation with examples

4. **Flexible Output Options:**
   - Return as string or save to file
   - Configurable JSON depth and compression
   - CSV delimiter and encoding options
   - UTF8 default with encoding choices

#### 🔧 Implementation Details
```powershell
# Core data extraction function
function Get-ExcelWorksheetData {
    param($Path, $WorksheetName, $HasHeaders)
    
    # Key features:
    # - Excel COM object creation with error handling
    # - Absolute path resolution (COM requirement)
    # - Used range detection and data extraction
    # - 2D array processing with proper indexing
    # - Date value conversion from Excel format
    # - Proper COM cleanup in finally block
}
```

#### 📊 Test Coverage
**Test Data Files:** 7 comprehensive test scenarios
- `simple.xlsx` - Basic data with headers
- `complex-data.xlsx` - Mixed data types, dates, numbers
- `empty.xlsx` - Edge case: empty worksheet
- `large-dataset.xlsx` - Performance testing
- `multiple-sheets.xlsx` - Multi-worksheet handling
- `no-headers.xlsx` - Data without headers
- `test.xlsm` - Macro-enabled Excel file

#### 🎯 Current Enhancement Pipeline
Based on backlog analysis (`ps/excel/ConvertFromExcel/backlog/tasks/`):
1. **Extended Type Handling** - Enhanced data type detection
2. **Table Format Output** - Structured table export options  
3. **Worksheet Pattern Matching** - Advanced worksheet selection

### Dependency Analysis Findings

#### Native vs Third-Party Evaluation
**Previous Dependencies (Removed):**
- ❌ `ImportExcel` module (3rd party) → ✅ Excel COM objects (native)
- ❌ `powershell-yaml` module (3rd party) → ✅ JSON focus (native)

**Current Architecture Benefits:**
- ✅ Enterprise security compliance
- ✅ Reduced attack surface  
- ✅ No package management complexity
- ✅ Predictable behavior in corporate environments

---

## 📚 Development Standards & Guidelines

### Code Style Requirements
```powershell
# Function naming: Verb-Noun pattern
ConvertFrom-ExcelToJson    # ✅ Correct
Excel-ToJson              # ❌ Incorrect

# Parameter validation - Always validate inputs
[ValidateScript({
    if (-not (Test-Path $_ -PathType Leaf)) {
        throw "File not found: $_"
    }
    return $true
})]

# Error handling - Use try/catch with logging
try {
    # Excel operations
} catch {
    Write-ConversionLog "Error: $($_.Exception.Message)" -Level Error
    throw
} finally {
    # COM cleanup - ALWAYS in finally block
}
```

### Module Structure Standards
```powershell
# Module Manifest (.psd1) - Key requirements
@{
    RootModule = 'ModuleName.psm1'
    ModuleVersion = 'X.Y.Z'                    # Semantic versioning
    CompatiblePSEditions = @('Desktop')        # COM objects require Desktop
    PowerShellVersion = '5.1'                  # Minimum version
    FunctionsToExport = @('Function1', 'Function2')  # Explicit exports
}

# Module Implementation (.psm1) - Structure
<# Header with synopsis, description, notes #>
#region Helper Functions
#region Public Functions  
Export-ModuleMember -Function @('PublicFunction1', 'PublicFunction2')
```

### Testing Standards
- **Test all Excel formats:** .xlsx, .xls, .xlsm, .xlsb
- **Edge cases:** Empty files, missing worksheets, no headers
- **Output validation:** Verify JSON/CSV format correctness
- **Memory testing:** Confirm COM object cleanup
- **Error scenarios:** Invalid paths, missing Excel installation

### Documentation Requirements
- **Function documentation:** Complete help with examples
- **Parameter descriptions:** Purpose and validation rules
- **Error conditions:** What can go wrong and why
- **Examples:** Real-world usage scenarios
- **Dependencies:** What's required for operation

---

## 🛡️ Security & Enterprise Guidelines

### Security Principles
1. **Input Validation:** Always validate file paths and parameters
2. **Path Security:** Use absolute paths, validate extensions
3. **COM Object Safety:** Proper creation, usage, and cleanup
4. **Error Information:** Don't expose sensitive system details
5. **Dependency Minimization:** Prefer native tools over third-party

### Enterprise Compatibility
```powershell
# Excel installation detection
function Test-ExcelInstallation {
    try {
        $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        return $true
    } catch {
        return $false
    }
}

# Always check before using COM objects
if (-not (Test-ExcelInstallation)) {
    throw "Microsoft Excel is not installed or accessible."
}
```

### Memory Management
```powershell
# COM object cleanup pattern - ALWAYS use
try {
    $excel = New-Object -ComObject Excel.Application
    # ... operations
} finally {
    # Cleanup in correct order
    if ($workbook) { 
        $workbook.Close($false)
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null
    }
    if ($excel) { 
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
    }
    # Force garbage collection
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
}
```

---

## 🎯 Current Project Status

### Active Development
- **Branch:** `feature/excel-converter`
- **Status:** Excel module functionality complete
- **Next Phase:** Enhancement features from backlog

### Completed Features
- ✅ Excel to JSON conversion with native tools
- ✅ Excel to CSV conversion with native tools  
- ✅ Comprehensive test suite and validation
- ✅ Windows dependency analysis utilities
- ✅ Enterprise-ready architecture with zero external dependencies

### Enhancement Pipeline
1. **Extended Type Handling** - Better data type detection and conversion
2. **Table Format Output** - Structured output options beyond JSON/CSV
3. **Worksheet Pattern Matching** - Advanced worksheet selection patterns

### Task Management
**System:** Backlog.md CLI tool
**Location:** `ps/excel/ConvertFromExcel/backlog/`
**Active Tasks:** 3 enhancement tasks in development pipeline

---

## 🚀 Quick Start for AI Assistants

### When Working on Excel Module
```bash
# Navigate to module directory
cd ps/excel/ConvertFromExcel/

# Read current implementation
# - ConvertFromExcel.psm1 (main code)
# - ConvertFromExcel.psd1 (manifest) 
# - CLAUDE.md (detailed guidelines)

# Check active tasks
# - backlog/tasks/ directory
# - Look for task-N - Description.md files

# Test your changes
# - Use test-data/ files for validation
# - Check test-output/ for expected results
```

### When Working on System Utilities
```bash
# Navigate to cmd utilities
cd cmd/

# Understand current tools:
# - analyze-dependencies.cmd (dependency analysis)
# - *-managedSoftware.cmd (software management)

# Follow Windows batch best practices
# - Parameter validation
# - Verbose/quiet mode support
# - Help documentation
```

### Before Making Changes
1. **Read existing code** to understand patterns and conventions
2. **Check CLAUDE.md** files for module-specific guidelines
3. **Review test data** to understand expected functionality
4. **Follow established error handling** and logging patterns
5. **Maintain enterprise compatibility** (no external dependencies)

---

## 📞 Support & Context

### Key Design Decisions
1. **Native Microsoft Tools Only** - For enterprise security and compliance
2. **PowerShell Desktop Edition** - Required for Excel COM objects  
3. **Comprehensive Error Handling** - Enterprise-grade reliability
4. **Zero External Dependencies** - Reduces security and maintenance overhead

### Common Issues & Solutions
- **Excel not installed:** Provide clear error message with installation guidance
- **COM object errors:** Always use try/finally with proper cleanup
- **File path issues:** Convert to absolute paths for COM compatibility
- **Memory leaks:** Implement garbage collection after COM operations

### Architecture Rationale
The project prioritizes **enterprise compatibility** and **security** over convenience features. This means:
- Longer, more complex code that uses native tools
- Extensive validation and error handling
- Comprehensive testing for edge cases
- Documentation for enterprise deployment scenarios

This approach makes the tools suitable for corporate environments with strict security requirements and dependency policies.

---

*This file serves as the central AI context for the i-script.one project. Keep it updated as the project evolves.*