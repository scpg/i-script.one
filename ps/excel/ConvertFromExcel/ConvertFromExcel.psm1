<#
.SYNOPSIS
PowerShell module for converting Excel files to JSON, YAML, and CSV formats.

.DESCRIPTION
This module provides functions for converting Excel worksheets to various data formats
including JSON, YAML, and CSV. It focuses specifically on data conversion and export.

.NOTES
Author: scpg
Version: 1.0.0
Date: 2025-09-01
License: MIT License (https://opensource.org/licenses/MIT)
Created with assistance from Claude.ai

.LINK
https://github.com/scpg/i-script.one
#>

#region Helper Functions

function Test-ExcelPath {
    <#
    .SYNOPSIS
    Validates if a path has a valid Excel file extension.
    
    .PARAMETER Path
    The file path to validate.
    
    .EXAMPLE
    Test-ExcelPath "C:\data\workbook.xlsx"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    $validExtensions = @('.xlsx', '.xls', '.xlsm', '.xlsb')
    $extension = [System.IO.Path]::GetExtension($Path)
    return $validExtensions -contains $extension
}

function Write-ConversionLog {
    <#
    .SYNOPSIS
    Internal logging function for the ConvertFromExcel module.
    
    .PARAMETER Message
    The message to log.
    
    .PARAMETER Level
    The log level (Info, Warning, Error).
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] [$Level] ConvertFromExcel: $Message"
    
    switch ($Level) {
        'Info' { Write-Host $logMessage -ForegroundColor Green }
        'Warning' { Write-Warning $logMessage }
        'Error' { Write-Error $logMessage }
    }
}

function Get-ExcelWorksheetData {
    <#
    .SYNOPSIS
    Internal function to read Excel worksheet data.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .PARAMETER WorksheetName
    The name of the worksheet to read.
    
    .PARAMETER HasHeaders
    Whether the first row contains headers.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders
    )
    
    try {
        # Check if ImportExcel module is available
        if (Get-Module -ListAvailable -Name ImportExcel) {
            Import-Module ImportExcel -ErrorAction Stop
            
            $params = @{
                Path = $Path
            }
            
            if ($WorksheetName) {
                $params.WorksheetName = $WorksheetName
            }
            
            if ($HasHeaders) {
                $params.HeaderRow = 1
            }
            
            $data = Import-Excel @params
            return $data
        }
        else {
            Write-ConversionLog "ImportExcel module not found. Install it with: Install-Module ImportExcel" -Level Warning
            throw "ImportExcel module is required for Excel file operations"
        }
    }
    catch {
        Write-ConversionLog "Error reading Excel file: $($_.Exception.Message)" -Level Error
        throw
    }
}

function Test-YamlModule {
    <#
    .SYNOPSIS
    Checks if PowerShell-Yaml module is available for YAML conversion.
    #>
    if (Get-Module -ListAvailable -Name powershell-yaml) {
        return $true
    }
    elseif (Get-Module -ListAvailable -Name PSYaml) {
        return $true
    }
    else {
        return $false
    }
}

#endregion

#region Public Functions

function ConvertFrom-ExcelToJson {
    <#
    .SYNOPSIS
    Converts Excel worksheet data to JSON format.
    
    .DESCRIPTION
    Reads data from an Excel worksheet and converts it to JSON format.
    Can output to a file or return as string.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .PARAMETER OutputPath
    The path where the JSON file will be saved. If not specified, returns JSON as string.
    
    .PARAMETER WorksheetName
    The name of the worksheet to convert. If not specified, uses the first worksheet.
    
    .PARAMETER HasHeaders
    Indicates whether the first row contains column headers.
    
    .PARAMETER Indent
    Number of spaces for JSON indentation. Default is 2.
    
    .PARAMETER Depth
    Maximum depth for JSON serialization. Default is 10.
    
    .EXAMPLE
    ConvertFrom-ExcelToJson -Path "C:\data\sales.xlsx" -OutputPath "C:\output\sales.json" -HasHeaders
    
    .EXAMPLE
    $jsonData = ConvertFrom-ExcelToJson -Path "C:\data\inventory.xlsx" -WorksheetName "Products" -HasHeaders
    
    .OUTPUTS
    String (if OutputPath not specified) or creates JSON file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders,
        
        [Parameter(Mandatory = $false)]
        [int]$Indent = 2,
        
        [Parameter(Mandatory = $false)]
        [int]$Depth = 10
    )
    
    try {
        if (-not (Test-ExcelPath -Path $Path)) {
            throw "Invalid Excel file format. Supported formats: .xlsx, .xls, .xlsm, .xlsb"
        }
        
        Write-ConversionLog "Converting Excel to JSON: $Path"
        
        $params = @{
            Path = $Path
            HasHeaders = $HasHeaders
        }
        
        if ($WorksheetName) {
            $params.WorksheetName = $WorksheetName
        }
        
        $data = Get-ExcelWorksheetData @params
        
        if (-not $data) {
            Write-ConversionLog "No data found in Excel worksheet" -Level Warning
            return $null
        }
        
        $jsonData = $data | ConvertTo-Json -Depth $Depth
        
        if ($OutputPath) {
            $jsonData | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-ConversionLog "Successfully converted to JSON: $OutputPath"
            return "JSON file created: $OutputPath"
        }
        else {
            Write-ConversionLog "Successfully converted Excel to JSON string"
            return $jsonData
        }
    }
    catch {
        Write-ConversionLog "Error converting Excel to JSON: $($_.Exception.Message)" -Level Error
        throw
    }
}

function ConvertFrom-ExcelToYaml {
    <#
    .SYNOPSIS
    Converts Excel worksheet data to YAML format.
    
    .DESCRIPTION
    Reads data from an Excel worksheet and converts it to YAML format.
    Can output to a file or return as string. Requires PowerShell-Yaml or PSYaml module.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .PARAMETER OutputPath
    The path where the YAML file will be saved. If not specified, returns YAML as string.
    
    .PARAMETER WorksheetName
    The name of the worksheet to convert. If not specified, uses the first worksheet.
    
    .PARAMETER HasHeaders
    Indicates whether the first row contains column headers.
    
    .EXAMPLE
    ConvertFrom-ExcelToYaml -Path "C:\data\config.xlsx" -OutputPath "C:\output\config.yaml" -HasHeaders
    
    .EXAMPLE
    $yamlData = ConvertFrom-ExcelToYaml -Path "C:\data\settings.xlsx" -WorksheetName "Configuration" -HasHeaders
    
    .OUTPUTS
    String (if OutputPath not specified) or creates YAML file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders
    )
    
    try {
        if (-not (Test-ExcelPath -Path $Path)) {
            throw "Invalid Excel file format. Supported formats: .xlsx, .xls, .xlsm, .xlsb"
        }
        
        if (-not (Test-YamlModule)) {
            Write-ConversionLog "YAML module not found. Install with: Install-Module powershell-yaml" -Level Warning
            throw "PowerShell-Yaml or PSYaml module is required for YAML conversion"
        }
        
        Write-ConversionLog "Converting Excel to YAML: $Path"
        
        $params = @{
            Path = $Path
            HasHeaders = $HasHeaders
        }
        
        if ($WorksheetName) {
            $params.WorksheetName = $WorksheetName
        }
        
        $data = Get-ExcelWorksheetData @params
        
        if (-not $data) {
            Write-ConversionLog "No data found in Excel worksheet" -Level Warning
            return $null
        }
        
        # Try to import YAML module
        try {
            Import-Module powershell-yaml -ErrorAction Stop
            $yamlData = $data | ConvertTo-Yaml
        }
        catch {
            try {
                Import-Module PSYaml -ErrorAction Stop
                $yamlData = $data | ConvertTo-Yaml
            }
            catch {
                throw "Unable to load YAML conversion module"
            }
        }
        
        if ($OutputPath) {
            $yamlData | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-ConversionLog "Successfully converted to YAML: $OutputPath"
            return "YAML file created: $OutputPath"
        }
        else {
            Write-ConversionLog "Successfully converted Excel to YAML string"
            return $yamlData
        }
    }
    catch {
        Write-ConversionLog "Error converting Excel to YAML: $($_.Exception.Message)" -Level Error
        throw
    }
}

function ConvertFrom-ExcelToCsv {
    <#
    .SYNOPSIS
    Converts Excel worksheet data to CSV format.
    
    .DESCRIPTION
    Reads data from an Excel worksheet and converts it to CSV format.
    Can output to a file or return as string.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .PARAMETER OutputPath
    The path where the CSV file will be saved. If not specified, returns CSV as string.
    
    .PARAMETER WorksheetName
    The name of the worksheet to convert. If not specified, uses the first worksheet.
    
    .PARAMETER HasHeaders
    Indicates whether the first row contains column headers.
    
    .PARAMETER Delimiter
    The delimiter character for CSV. Default is comma (,).
    
    .PARAMETER NoTypeInformation
    Excludes type information from CSV output.
    
    .EXAMPLE
    ConvertFrom-ExcelToCsv -Path "C:\data\employees.xlsx" -OutputPath "C:\output\employees.csv" -HasHeaders
    
    .EXAMPLE
    $csvData = ConvertFrom-ExcelToCsv -Path "C:\data\products.xlsx" -WorksheetName "Inventory" -HasHeaders -Delimiter ";"
    
    .OUTPUTS
    String (if OutputPath not specified) or creates CSV file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders,
        
        [Parameter(Mandatory = $false)]
        [char]$Delimiter = ',',
        
        [Parameter(Mandatory = $false)]
        [switch]$NoTypeInformation
    )
    
    try {
        if (-not (Test-ExcelPath -Path $Path)) {
            throw "Invalid Excel file format. Supported formats: .xlsx, .xls, .xlsm, .xlsb"
        }
        
        Write-ConversionLog "Converting Excel to CSV: $Path"
        
        $params = @{
            Path = $Path
            HasHeaders = $HasHeaders
        }
        
        if ($WorksheetName) {
            $params.WorksheetName = $WorksheetName
        }
        
        $data = Get-ExcelWorksheetData @params
        
        if (-not $data) {
            Write-ConversionLog "No data found in Excel worksheet" -Level Warning
            return $null
        }
        
        if ($OutputPath) {
            $exportParams = @{
                Path = $OutputPath
                Delimiter = $Delimiter
            }
            
            if ($NoTypeInformation) {
                $exportParams.NoTypeInformation = $true
            }
            
            $data | Export-Csv @exportParams
            Write-ConversionLog "Successfully converted to CSV: $OutputPath"
            return "CSV file created: $OutputPath"
        }
        else {
            $csvParams = @{
                Delimiter = $Delimiter
            }
            
            if ($NoTypeInformation) {
                $csvParams.NoTypeInformation = $true
            }
            
            $csvData = $data | ConvertTo-Csv @csvParams | Out-String
            Write-ConversionLog "Successfully converted Excel to CSV string"
            return $csvData
        }
    }
    catch {
        Write-ConversionLog "Error converting Excel to CSV: $($_.Exception.Message)" -Level Error
        throw
    }
}

#endregion

# Export module members
Export-ModuleMember -Function @(
    'ConvertFrom-ExcelToJson',
    'ConvertFrom-ExcelToYaml',
    'ConvertFrom-ExcelToCsv'
)