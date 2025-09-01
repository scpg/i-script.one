<#
.SYNOPSIS
PowerShell module for converting Excel files to JSON and CSV formats using native Microsoft tools.

.DESCRIPTION
This module provides functions for converting Excel worksheets to JSON and CSV formats
using only native Microsoft Excel COM objects. No third-party dependencies required.
Perfect for enterprise environments with strict security requirements.

.NOTES
Author: scpg
Version: 1.0.0
Date: 2025-09-01
License: MIT License (https://opensource.org/licenses/MIT)
Created with assistance from Claude.ai

Requirements: Microsoft Excel installed (uses Excel COM object)
Compatibility: Windows PowerShell 5.1+ (Desktop edition required for COM objects)

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

function Test-ExcelInstallation {
    <#
    .SYNOPSIS
    Tests if Microsoft Excel is installed and accessible via COM.
    
    .DESCRIPTION
    Checks if Excel COM object can be created, which indicates Excel is properly installed.
    
    .OUTPUTS
    Boolean indicating if Excel is available.
    #>
    try {
        $excel = New-Object -ComObject Excel.Application -ErrorAction Stop
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Get-ExcelWorksheetData {
    <#
    .SYNOPSIS
    Internal function to read Excel worksheet data using COM objects.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .PARAMETER WorksheetName
    The name of the worksheet to read.
    
    .PARAMETER HasHeaders
    Whether the first row contains headers.
    
    .OUTPUTS
    Array of PSCustomObjects representing the worksheet data.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders
    )
    
    if (-not (Test-ExcelInstallation)) {
        throw "Microsoft Excel is not installed or accessible. This module requires Excel COM objects."
    }
    
    $excel = $null
    $workbook = $null
    
    try {
        Write-ConversionLog "Creating Excel COM object"
        $excel = New-Object -ComObject Excel.Application
        $excel.Visible = $false
        $excel.DisplayAlerts = $false
        $excel.ScreenUpdating = $false
        
        Write-ConversionLog "Opening workbook: $Path"
        $workbook = $excel.Workbooks.Open($Path)
        
        # Select worksheet
        if ($WorksheetName) {
            try {
                $worksheet = $workbook.Worksheets.Item($WorksheetName)
                Write-ConversionLog "Using worksheet: $WorksheetName"
            }
            catch {
                throw "Worksheet '$WorksheetName' not found in workbook"
            }
        }
        else {
            $worksheet = $workbook.Worksheets.Item(1)
            Write-ConversionLog "Using first worksheet: $($worksheet.Name)"
        }
        
        # Get used range
        $usedRange = $worksheet.UsedRange
        if ($null -eq $usedRange) {
            Write-ConversionLog "Worksheet is empty" -Level Warning
            return @()
        }
        
        Write-ConversionLog "Reading data from range: $($usedRange.Address)"
        
        # Get data as 2D array
        $data = $usedRange.Value2
        
        if ($null -eq $data) {
            return @()
        }
        
        # Convert to PowerShell objects
        $result = @()
        
        if ($data -is [System.Array] -and $data.Rank -eq 2) {
            # Multi-dimensional array (multiple rows/columns)
            $rowCount = $data.GetLength(0)
            $colCount = $data.GetLength(1)
            
            Write-ConversionLog "Processing $rowCount rows and $colCount columns"
            
            # Get headers
            $headers = @()
            if ($HasHeaders -and $rowCount -gt 1) {
                for ($col = 1; $col -le $colCount; $col++) {
                    $headerValue = $data[1, $col]
                    $headers += if ($null -eq $headerValue -or $headerValue -eq "") { 
                        "Column$col" 
                    } else { 
                        $headerValue.ToString() 
                    }
                }
                $startRow = 2
            }
            else {
                for ($col = 1; $col -le $colCount; $col++) {
                    $headers += "Column$col"
                }
                $startRow = 1
            }
            
            # Process data rows
            for ($row = $startRow; $row -le $rowCount; $row++) {
                $rowObject = [PSCustomObject]@{}
                $hasData = $false
                
                for ($col = 1; $col -le $colCount; $col++) {
                    $cellValue = $data[$row, $col]
                    
                    # Convert Excel values to appropriate types
                    if ($null -ne $cellValue -and $cellValue -ne "") {
                        $hasData = $true
                        # Handle Excel date values
                        if ($cellValue -is [double] -and $cellValue -gt 25569) {
                            try {
                                $cellValue = [DateTime]::FromOADate($cellValue)
                            }
                            catch {
                                # Keep as number if date conversion fails
                            }
                        }
                    }
                    
                    $rowObject | Add-Member -MemberType NoteProperty -Name $headers[$col - 1] -Value $cellValue
                }
                
                # Only add rows that have some data
                if ($hasData) {
                    $result += $rowObject
                }
            }
        }
        elseif ($data -is [System.Array] -and $data.Rank -eq 1) {
            # Single row or column
            Write-ConversionLog "Processing single row/column with $($data.Length) values"
            
            if ($HasHeaders -and $data.Length -gt 1) {
                $headers = @($data[0].ToString())
                for ($i = 1; $i -lt $data.Length; $i++) {
                    $rowObject = [PSCustomObject]@{}
                    $rowObject | Add-Member -MemberType NoteProperty -Name $headers[0] -Value $data[$i]
                    $result += $rowObject
                }
            }
            else {
                for ($i = 0; $i -lt $data.Length; $i++) {
                    $rowObject = [PSCustomObject]@{}
                    $rowObject | Add-Member -MemberType NoteProperty -Name "Column1" -Value $data[$i]
                    $result += $rowObject
                }
            }
        }
        else {
            # Single cell
            Write-ConversionLog "Processing single cell value"
            $rowObject = [PSCustomObject]@{}
            $rowObject | Add-Member -MemberType NoteProperty -Name "Column1" -Value $data
            $result += $rowObject
        }
        
        Write-ConversionLog "Successfully processed $($result.Count) data rows"
        return $result
    }
    catch {
        Write-ConversionLog "Error reading Excel file: $($_.Exception.Message)" -Level Error
        throw
    }
    finally {
        # Clean up COM objects
        if ($workbook) {
            try {
                $workbook.Close($false)
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($workbook) | Out-Null
            }
            catch {
                Write-ConversionLog "Warning: Could not properly close workbook" -Level Warning
            }
        }
        
        if ($excel) {
            try {
                $excel.Quit()
                [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel) | Out-Null
            }
            catch {
                Write-ConversionLog "Warning: Could not properly quit Excel" -Level Warning
            }
        }
        
        # Force garbage collection to clean up COM objects
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
    }
}

#endregion

#region Public Functions

function ConvertFrom-ExcelToJson {
    <#
    .SYNOPSIS
    Converts Excel worksheet data to JSON format using native Microsoft Excel COM objects.
    
    .DESCRIPTION
    Reads data from an Excel worksheet and converts it to JSON format using only native
    Microsoft tools. Requires Microsoft Excel to be installed.
    
    .PARAMETER Path
    The path to the Excel file.
    
    .PARAMETER OutputPath
    The path where the JSON file will be saved. If not specified, returns JSON as string.
    
    .PARAMETER WorksheetName
    The name of the worksheet to convert. If not specified, uses the first worksheet.
    
    .PARAMETER HasHeaders
    Indicates whether the first row contains column headers.
    
    .PARAMETER Depth
    Maximum depth for JSON serialization. Default is 10.
    
    .PARAMETER Compress
    Compress JSON output (no indentation). Default is false for readable output.
    
    .EXAMPLE
    ConvertFrom-ExcelToJson -Path "C:\data\sales.xlsx" -OutputPath "C:\output\sales.json" -HasHeaders
    
    .EXAMPLE
    $jsonData = ConvertFrom-ExcelToJson -Path "C:\data\inventory.xlsx" -WorksheetName "Products" -HasHeaders
    
    .EXAMPLE
    ConvertFrom-ExcelToJson -Path "C:\reports\data.xlsx" -HasHeaders -Compress
    
    .OUTPUTS
    String (if OutputPath not specified) or file path confirmation message
    
    .NOTES
    Requires Microsoft Excel to be installed for COM object access.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            if (-not (Test-ExcelPath $_)) {
                throw "Invalid Excel file format. Supported formats: .xlsx, .xls, .xlsm, .xlsb"
            }
            return $true
        })]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
        [string]$WorksheetName,
        
        [Parameter(Mandatory = $false)]
        [switch]$HasHeaders,
        
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100)]
        [int]$Depth = 10,
        
        [Parameter(Mandatory = $false)]
        [switch]$Compress
    )
    
    try {
        Write-ConversionLog "Starting Excel to JSON conversion: $Path"
        
        $data = Get-ExcelWorksheetData -Path $Path -WorksheetName $WorksheetName -HasHeaders:$HasHeaders
        
        if (-not $data -or $data.Count -eq 0) {
            Write-ConversionLog "No data found in Excel worksheet" -Level Warning
            if ($OutputPath) {
                "[]" | Out-File -FilePath $OutputPath -Encoding UTF8
                return "Empty JSON file created: $OutputPath"
            }
            return "[]"
        }
        
        Write-ConversionLog "Converting $($data.Count) rows to JSON"
        
        # Convert to JSON
        if ($Compress) {
            $jsonData = $data | ConvertTo-Json -Depth $Depth -Compress
        }
        else {
            $jsonData = $data | ConvertTo-Json -Depth $Depth
        }
        
        if ($OutputPath) {
            $jsonData | Out-File -FilePath $OutputPath -Encoding UTF8
            Write-ConversionLog "Successfully created JSON file: $OutputPath"
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

function ConvertFrom-ExcelToCsv {
    <#
    .SYNOPSIS
    Converts Excel worksheet data to CSV format using native Microsoft Excel COM objects.
    
    .DESCRIPTION
    Reads data from an Excel worksheet and converts it to CSV format using only native
    Microsoft tools. Requires Microsoft Excel to be installed.
    
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
    Excludes PowerShell type information from CSV output. Default is true.
    
    .PARAMETER Encoding
    The encoding for the output file. Default is UTF8.
    
    .EXAMPLE
    ConvertFrom-ExcelToCsv -Path "C:\data\employees.xlsx" -OutputPath "C:\output\employees.csv" -HasHeaders
    
    .EXAMPLE
    $csvData = ConvertFrom-ExcelToCsv -Path "C:\data\products.xlsx" -WorksheetName "Inventory" -HasHeaders -Delimiter ";"
    
    .EXAMPLE
    ConvertFrom-ExcelToCsv -Path "C:\reports\data.xlsx" -HasHeaders -Delimiter "|"
    
    .OUTPUTS
    String (if OutputPath not specified) or file path confirmation message
    
    .NOTES
    Requires Microsoft Excel to be installed for COM object access.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "File not found: $_"
            }
            if (-not (Test-ExcelPath $_)) {
                throw "Invalid Excel file format. Supported formats: .xlsx, .xls, .xlsm, .xlsb"
            }
            return $true
        })]
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
        [switch]$NoTypeInformation = $true,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('UTF8', 'ASCII', 'Unicode', 'UTF32')]
        [string]$Encoding = 'UTF8'
    )
    
    try {
        Write-ConversionLog "Starting Excel to CSV conversion: $Path"
        
        $data = Get-ExcelWorksheetData -Path $Path -WorksheetName $WorksheetName -HasHeaders:$HasHeaders
        
        if (-not $data -or $data.Count -eq 0) {
            Write-ConversionLog "No data found in Excel worksheet" -Level Warning
            if ($OutputPath) {
                "" | Out-File -FilePath $OutputPath -Encoding $Encoding
                return "Empty CSV file created: $OutputPath"
            }
            return ""
        }
        
        Write-ConversionLog "Converting $($data.Count) rows to CSV"
        
        if ($OutputPath) {
            $exportParams = @{
                Path = $OutputPath
                Delimiter = $Delimiter
                Encoding = $Encoding
            }
            
            if ($NoTypeInformation) {
                $exportParams.NoTypeInformation = $true
            }
            
            $data | Export-Csv @exportParams
            Write-ConversionLog "Successfully created CSV file: $OutputPath"
            return "CSV file created: $OutputPath"
        }
        else {
            $convertParams = @{
                Delimiter = $Delimiter
            }
            
            if ($NoTypeInformation) {
                $convertParams.NoTypeInformation = $true
            }
            
            $csvData = $data | ConvertTo-Csv @convertParams | Out-String
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
    'ConvertFrom-ExcelToCsv'
)