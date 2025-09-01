# ConvertFromExcel Module - Development Guidelines

## Module Overview
ConvertFromExcel is a PowerShell module for converting Excel files to JSON and CSV formats using only native Microsoft tools. Perfect for enterprise environments with strict security requirements. No third-party dependencies required.

## Module Structure
- **ConvertFromExcel.psd1** - Module manifest with metadata and exported functions
- **ConvertFromExcel.psm1** - Main module implementation with all functions
- **CLAUDE.md** - This file containing development guidelines

## Functions
1. `ConvertFrom-ExcelToJson` - Convert Excel to JSON format
2. `ConvertFrom-ExcelToCsv` - Convert Excel to CSV format

## Dependencies
- **Microsoft Excel** - Required for COM object access (Excel must be installed)
- **Windows PowerShell 5.1+** - Desktop edition required for COM objects
- **No third-party modules** - Uses only native Microsoft technologies

## Development Standards

### Code Style
- Follow existing PowerShell conventions (Verb-Noun naming)
- Use `ConvertFrom-` prefix for all public functions
- Include comprehensive parameter validation
- Provide detailed help documentation with examples
- Use `Write-ConversionLog` for consistent logging

### Error Handling
- Always use try/catch blocks for external operations
- Validate file paths and extensions before processing
- Check for required modules and provide helpful error messages
- Log errors with appropriate severity levels

### Function Parameters
- **Path** - Always validate Excel file existence and format
- **OutputPath** - Optional, if not provided return as string
- **WorksheetName** - Optional, defaults to first worksheet
- **HasHeaders** - Switch parameter for header row detection
- Format-specific parameters (Delimiter for CSV, Depth for JSON, etc.)

### Testing Approach
- Test with various Excel formats (.xlsx, .xls, .xlsm, .xlsb)
- Test with and without headers
- Test empty worksheets and missing files
- Test with different worksheet names
- Verify output formats are valid JSON/YAML/CSV

### Module Versioning
- Follow semantic versioning (MAJOR.MINOR.PATCH)
- Update version in both .psd1 and module documentation
- Update release notes for each version

## Design Decisions

### Single Module Approach
- All conversion functions in one module for simplicity
- Shared helper functions for common operations
- Consistent logging and error handling across functions

### Flexible Output
- Functions can either save to file or return as string
- Allows for pipeline integration and direct file export
- Consistent return messages for file operations

### Enterprise-Ready Design
- No external dependencies or third-party modules
- Uses native Microsoft Excel COM objects
- Comprehensive Excel installation detection
- Proper COM object cleanup and memory management

## Usage Examples
```powershell
# Import module
Import-Module .\ConvertFromExcel.psd1

# Convert to JSON file
ConvertFrom-ExcelToJson -Path "data.xlsx" -OutputPath "output.json" -HasHeaders

# Convert to compressed JSON string
$jsonData = ConvertFrom-ExcelToJson -Path "config.xlsx" -WorksheetName "Settings" -HasHeaders -Compress

# Convert to CSV with semicolon delimiter
ConvertFrom-ExcelToCsv -Path "report.xlsx" -OutputPath "export.csv" -Delimiter ";" -HasHeaders
```

## Enterprise Features
- Excel installation detection and validation
- Comprehensive COM object cleanup
- Proper memory management for large files
- Support for all Excel formats (.xlsx, .xls, .xlsm, .xlsb)
- Detailed error handling and logging
- Date/time value conversion from Excel format


## Future Enhancements
- Support for multiple worksheets in single operation
- Batch conversion of multiple Excel files
- Custom data transformation options
- Support for additional output formats (XML, TSV)
- Excel formula evaluation options