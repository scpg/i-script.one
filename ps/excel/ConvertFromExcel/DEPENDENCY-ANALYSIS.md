# Dependency Analysis for ConvertFromExcel Module

## Current Dependencies

### ImportExcel Module (3rd Party)
- **Purpose:** Reading Excel files (.xlsx, .xls, .xlsm, .xlsb)
- **Developer:** Doug Finke (Community)
- **Status:** External dependency

### powershell-yaml Module (3rd Party)
- **Purpose:** Converting data to YAML format
- **Developer:** Community
- **Status:** External dependency

## Native/Microsoft Alternatives

### 1. Excel File Reading Alternatives

#### Option A: Excel COM Object (Recommended for Windows)
```powershell
function Read-ExcelWithCOM {
    param($Path, $WorksheetName, $HasHeaders)
    
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    
    try {
        $workbook = $excel.Workbooks.Open($Path)
        $worksheet = if ($WorksheetName) { 
            $workbook.Worksheets.Item($WorksheetName) 
        } else { 
            $workbook.Worksheets.Item(1) 
        }
        
        $range = $worksheet.UsedRange
        $data = $range.Value2
        
        # Convert to PowerShell objects
        # Implementation details...
        
        return $convertedData
    }
    finally {
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
    }
}
```

**Pros:**
- ✅ Native Microsoft technology
- ✅ No external package dependencies
- ✅ Full Excel feature support
- ✅ Handles all Excel formats

**Cons:**
- ❌ Requires Microsoft Excel installed
- ❌ COM objects can be slower
- ❌ Memory management complexity
- ❌ Not cross-platform (Windows only)

#### Option B: CSV Conversion Method
```powershell
function Read-ExcelViaCSV {
    param($Path, $WorksheetName)
    
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    
    try {
        $workbook = $excel.Workbooks.Open($Path)
        $worksheet = if ($WorksheetName) { 
            $workbook.Worksheets.Item($WorksheetName) 
        } else { 
            $workbook.Worksheets.Item(1) 
        }
        
        $tempCSV = [System.IO.Path]::GetTempFileName() + ".csv"
        $worksheet.SaveAs($tempCSV, 6) # CSV format
        
        $data = Import-Csv $tempCSV
        Remove-Item $tempCSV
        
        return $data
    }
    finally {
        $workbook.Close($false)
        $excel.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
    }
}
```

**Pros:**
- ✅ Uses native CSV import (very reliable)
- ✅ Cleaner data handling
- ✅ Automatic type conversion

**Cons:**
- ❌ Still requires Excel installed
- ❌ Temporary file creation
- ❌ Single worksheet at a time

#### Option C: .NET System.IO.Packaging (For .xlsx only)
```powershell
function Read-ExcelWithPackaging {
    param($Path)
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.Xml
    
    # Open .xlsx as ZIP file and parse XML
    # Complex implementation for XML parsing
    # Limited functionality compared to full Excel support
}
```

**Pros:**
- ✅ No Excel installation required
- ✅ Cross-platform compatible
- ✅ Native .NET libraries

**Cons:**
- ❌ Complex implementation
- ❌ Limited to .xlsx format only
- ❌ No formula evaluation
- ❌ Manual XML parsing required

### 2. YAML Conversion Alternatives

#### Option A: Manual YAML Generation (Recommended)
```powershell
function ConvertTo-SimpleYaml {
    param($Data, $Depth = 0)
    
    $indent = "  " * $Depth
    $yaml = ""
    
    if ($Data -is [Array]) {
        foreach ($item in $Data) {
            $yaml += "$indent- "
            if ($item -is [PSCustomObject]) {
                $yaml += "`n"
                $yaml += ConvertTo-SimpleYaml $item ($Depth + 1)
            } else {
                $yaml += "$item`n"
            }
        }
    } elseif ($Data -is [PSCustomObject]) {
        $Data.PSObject.Properties | ForEach-Object {
            $value = $_.Value
            if ($value -is [string] -and ($value -match '\W' -or $value -match '^[0-9]')) {
                $yaml += "$indent$($_.Name): `"$value`"`n"
            } else {
                $yaml += "$indent$($_.Name): $value`n"
            }
        }
    }
    
    return $yaml
}
```

**Pros:**
- ✅ Pure PowerShell implementation
- ✅ No external dependencies
- ✅ Customizable output format
- ✅ Cross-platform compatible

**Cons:**
- ❌ Limited YAML features
- ❌ No complex data type support
- ❌ Manual escaping required
- ❌ May not handle all edge cases

#### Option B: JSON-to-YAML Style Conversion
```powershell
function ConvertTo-YamlStyle {
    param($Data)
    
    $json = $Data | ConvertTo-Json -Depth 10
    # Convert JSON syntax to YAML-like format
    $yaml = $json -replace '^\s*{', '' -replace '}\s*$', ''
    $yaml = $yaml -replace '^\s*"([^"]+)":\s*', '${1}: '
    $yaml = $yaml -replace ',\s*$', ''
    
    return $yaml
}
```

**Pros:**
- ✅ Uses native JSON conversion
- ✅ Handles complex nested data
- ✅ No external dependencies

**Cons:**
- ❌ Not true YAML format
- ❌ Limited formatting options
- ❌ May not be valid YAML

## Recommended Approach: Hybrid Implementation

### Strategy: Progressive Fallback
1. **Try ImportExcel** (if available) - Best performance and features
2. **Fallback to Excel COM** (if Excel installed) - Native Microsoft solution
3. **Error gracefully** with helpful messages

### Strategy: Optional YAML
1. **Try powershell-yaml** (if available) - Full YAML support
2. **Fallback to simple YAML** generation - Basic functionality
3. **Always support JSON** - Native and reliable

## Implementation Recommendation

Create a **dependency-aware module** that:
- Detects available tools at runtime
- Uses the best available option
- Provides clear error messages about missing dependencies
- Offers installation guidance

### Module Structure:
```powershell
# Test for optimal dependencies
if (Get-Module -ListAvailable ImportExcel) {
    # Use ImportExcel for best performance
} elseif (Test-Path "HKLM:\Software\Microsoft\Office") {
    # Use Excel COM object
} else {
    # Provide clear guidance for user
    throw "Excel reading requires either ImportExcel module or Microsoft Excel installation"
}
```

## Summary

**For Excel Reading:**
- **Best:** ImportExcel module (but 3rd party)
- **Native Alternative:** Excel COM object (requires Excel installed)
- **Most Compatible:** CSV conversion method

**For YAML:**
- **Best:** powershell-yaml module (but 3rd party)  
- **Native Alternative:** Manual YAML generation (limited features)
- **Always Available:** JSON conversion (native)

**Recommendation:** Implement the hybrid approach for maximum flexibility and user choice.