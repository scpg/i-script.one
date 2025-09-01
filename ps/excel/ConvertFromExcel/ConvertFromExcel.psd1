@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ConvertFromExcel.psm1'
    
    # Version number of this module.
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions (Desktop required for Excel COM)
    CompatiblePSEditions = @('Desktop')
    
    # ID used to uniquely identify this module
    GUID = '12345678-1234-1234-1234-123456789012'
    
    # Author of this module
    Author = 'scpg'
    
    # Company or vendor of this module
    CompanyName = 'i-script.one'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 scpg. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module for converting Excel files to JSON and CSV formats using native Microsoft tools'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
    FunctionsToExport = @(
        'ConvertFrom-ExcelToJson',
        'ConvertFrom-ExcelToCsv'
    )
    
    # Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = '*'
    
    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport = @()
    
    # List of all modules packaged with this module
    ModuleList = @()
    
    # List of all files packaged with this module
    FileList = @()
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
    PrivateData = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags = @('Excel', 'Converter', 'JSON', 'CSV', 'Data', 'Enterprise', 'Native')
            
            # A URL to the license for this module.
            LicenseUri = 'https://opensource.org/licenses/MIT'
            
            # A URL to the main website for this project.
            ProjectUri = 'https://github.com/scpg/i-script.one'
            
            # ReleaseNotes of this module
            ReleaseNotes = 'Enterprise-ready module using native Microsoft tools for converting Excel files to JSON and CSV formats'
        }
    }
}