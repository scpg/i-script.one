# Excel PowerShell Modules

This directory contains PowerShell modules for working with Excel files.

## Module Structure

Each Excel-related module is organized in its own subdirectory to allow for better organization and future expansion.

## Available Modules

### ConvertFromExcel
Located in: `.\ConvertFromExcel\`

A PowerShell module for converting Excel files to various formats using only native Microsoft tools:
- **JSON** conversion with configurable depth and formatting
- **CSV** conversion with custom delimiters
- **Enterprise-ready** with zero third-party dependencies

**Functions:**
- `ConvertFrom-ExcelToJson`
- `ConvertFrom-ExcelToCsv`

**Quick Start:**
```powershell
# Navigate to the module directory
cd .\ConvertFromExcel\

# Verify Excel is installed (required for COM objects)
if (-not (Test-Path "HKLM:\Software\Microsoft\Office")) {
    Write-Warning "Microsoft Excel may not be installed"
}

# Import the module
Import-Module .\ConvertFromExcel.psd1

# Create test data and run tests
.\Create-TestData.ps1
.\Test-Module.ps1 -CreateTestData -Verbose
```

**Documentation:**
- `CLAUDE.md` - Development guidelines and module specifications
- `TESTING.md` - Comprehensive testing guide
- `DEVELOPMENT.md` - Best practices for development workflow

## Enterprise Benefits

- **Zero third-party dependencies** - Uses only native Microsoft technologies
- **Corporate security compliance** - No external modules to audit
- **Easy deployment** - Works in restricted environments
- **Excel COM integration** - Full native Excel feature support

## Future Modules

This structure allows for easy addition of other Excel-related modules such as:
- **ExcelAnalyzer** - Module for analyzing Excel file structure and content
- **ExcelTemplate** - Module for creating Excel templates and reports
- **ExcelValidator** - Module for validating Excel data against schemas
- **ConvertToExcel** - Module for converting various formats to Excel

## Directory Structure

```
excel/
├── README.md                    # This file
├── ConvertFromExcel/           # Excel conversion module
│   ├── ConvertFromExcel.psd1   # Module manifest
│   ├── ConvertFromExcel.psm1   # Module implementation
│   ├── CLAUDE.md               # Development guidelines
│   ├── TESTING.md              # Testing guide
│   ├── DEVELOPMENT.md          # Development workflow
│   ├── Create-TestData.ps1     # Test data generator
│   ├── Test-Module.ps1         # Automated test suite
│   ├── Reload-Module.ps1       # Development helper
│   ├── test-data/              # Sample Excel files
│   └── test-output/            # Generated test files
└── [Future modules...]         # Additional Excel modules
```

## Usage Notes

- Each module is self-contained with its own documentation and test suite
- Navigate to the specific module directory before running scripts
- Follow the development guidelines in each module's CLAUDE.md file
- Use the provided test scripts to verify functionality