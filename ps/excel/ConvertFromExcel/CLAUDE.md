# ConvertFromExcel Module - Development Guidelines

## Module Overview
ConvertFromExcel is a PowerShell module for converting Excel files to JSON, YAML, and CSV formats. It follows PowerShell naming conventions and provides comprehensive error handling.

## Module Structure
- **ConvertFromExcel.psd1** - Module manifest with metadata and exported functions
- **ConvertFromExcel.psm1** - Main module implementation with all functions
- **CLAUDE.md** - This file containing development guidelines

## Functions
1. `ConvertFrom-ExcelToJson` - Convert Excel to JSON format
2. `ConvertFrom-ExcelToYaml` - Convert Excel to YAML format  
3. `ConvertFrom-ExcelToCsv` - Convert Excel to CSV format

## Dependencies
- **ImportExcel** - Required for reading Excel files (`Install-Module ImportExcel`)
- **powershell-yaml** or **PSYaml** - Required for YAML conversion (`Install-Module powershell-yaml`)

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

### Module Dependencies
- Graceful handling when required modules are missing
- Clear installation instructions in error messages
- Support for multiple YAML modules (powershell-yaml or PSYaml)

## Usage Examples
```powershell
# Import module
Import-Module .\ConvertFromExcel.psd1

# Convert to JSON file
ConvertFrom-ExcelToJson -Path "data.xlsx" -OutputPath "output.json" -HasHeaders

# Convert to YAML string
$yamlData = ConvertFrom-ExcelToYaml -Path "config.xlsx" -WorksheetName "Settings" -HasHeaders

# Convert to CSV with semicolon delimiter
ConvertFrom-ExcelToCsv -Path "report.xlsx" -OutputPath "export.csv" -Delimiter ";" -HasHeaders
```

## Future Enhancements
- Support for multiple worksheets in single operation
- Batch conversion of multiple Excel files
- Custom data transformation options
- Integration with cloud storage services
- Support for additional output formats (XML, TSV)