@echo off
REM  ************************************************************
REM  * @author scpg
REM  * @version 1.0
REM  * @date 2025-08-07
REM  * @license "MIT License" https://opensource.org/licenses/MIT
REM  *
REM  * Analyze runtime dependencies and redistributables
REM  * Usage: analyze-dependencies.cmd [-v|--verbose] [-q|--quiet] [-h|--help]
REM  *
REM  * ASCII Banner generated using: https://manytools.org/hacker-tools/ascii-banner/ 
REM  ************************************************************
setlocal enabledelayedexpansion

REM Set default verbosity level (0=quiet, 1=normal, 2=verbose)
set VERBOSE=1

REM Parse command line arguments
:parse_args
if "%1"=="" goto :main
if /i "%1"=="-v" set VERBOSE=2 & shift & goto :parse_args
if /i "%1"=="--verbose" set VERBOSE=2 & shift & goto :parse_args
if /i "%1"=="-q" set VERBOSE=0 & shift & goto :parse_args
if /i "%1"=="--quiet" set VERBOSE=0 & shift & goto :parse_args
if /i "%1"=="-h" goto :show_help
if /i "%1"=="--help" goto :show_help
echo Unknown parameter: %1
goto :show_help

:show_help
echo Usage: %~nx0 [options]
echo.
echo Options:
echo   -v, --verbose    Enable verbose output
echo   -q, --quiet      Quiet mode (minimal output)
echo   -h, --help       Show this help message
echo.
echo This script analyzes runtime dependencies and redistributables
echo that might be safe to remove. It does NOT automatically remove anything.
echo.
echo Examples:
echo   %~nx0              Run with normal output
echo   %~nx0 -v           Run with verbose output
echo   %~nx0 --quiet      Run with minimal output
exit /b 0

:main
REM Logging functions
goto :skip_functions

:log_verbose
if %VERBOSE% geq 2 echo [VERBOSE] %*
goto :eof

:log_info
if %VERBOSE% geq 1 echo [INFO] %*
goto :eof

:log_quiet
if %VERBOSE% geq 0 echo %*
goto :eof

:log_error
echo [ERROR] %*
goto :eof

:log_warning
echo [WARNING] %*
goto :eof

:skip_functions

call :log_info "Analyzing runtime dependencies and redistributables..."

REM get date and time
For /f "tokens=1-3 delims=/ " %%a in ('date /t') do (set myDate=%%c%%a%%b)
For /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set myTime=%%a%%b)

set "timeStamp=%myDate%-%myTime%"
set "scriptName=analyze-dependencies"
set "outputFolder=%TEMP%\%scriptName%_%timeStamp%_%random%"

call :log_verbose "Creating output folder: %outputFolder%"
mkdir "%outputFolder%" || (
    call :log_error "Failed to create output folder '%outputFolder%'"
    exit /b 1
)

REM Files for analysis
set "allPackagesFile=%outputFolder%\all-packages.txt"
set "dependenciesFile=%outputFolder%\dependencies.txt"
set "applicationsFile=%outputFolder%\applications.txt"

call :log_verbose "Getting list of all installed packages..."
winget list --source=winget --disable-interactivity > "%allPackagesFile%"

call :log_info "Extracting runtime dependencies..."

REM Extract dependencies using PowerShell with pattern matching
powershell -Command "Get-Content '%allPackagesFile%' | Select-Object -Skip 2 | ForEach-Object { if ($_ -match '^\s*(.+?)\s+(\S+)\s+(\S+)\s*$' -and ($matches[2] -like '*VCRedist*' -or $matches[2] -like '*DotNet*' -or $matches[2] -like '*DirectX*' -or $matches[2] -like '*XNA*' -or $matches[2] -like '*EdgeWebView*' -or $matches[2] -like '*OpenAL*' -or $matches[2] -like '*PhysX*' -or $matches[2] -like '*Redistributable*')) { $matches[1].Trim() + ' | ' + $matches[2] + ' | ' + $matches[3] } } | Where-Object { $_ -ne '' }" > "%dependenciesFile%"

call :log_info "Extracting application software..."

REM Extract non-dependency packages
powershell -Command "Get-Content '%allPackagesFile%' | Select-Object -Skip 2 | ForEach-Object { if ($_ -match '^\s*(.+?)\s+(\S+)\s+(\S+)\s*$' -and -not ($matches[2] -like '*VCRedist*' -or $matches[2] -like '*DotNet*' -or $matches[2] -like '*DirectX*' -or $matches[2] -like '*XNA*' -or $matches[2] -like '*EdgeWebView*' -or $matches[2] -like '*OpenAL*' -or $matches[2] -like '*PhysX*' -or $matches[2] -like '*Redistributable*' -or $matches[2] -like '*Microsoft.UI*' -or $matches[2] -like '*WindowsAppRuntime*')) { $matches[1].Trim() + ' | ' + $matches[2] + ' | ' + $matches[3] } } | Where-Object { $_ -ne '' }" > "%applicationsFile%"

echo.
echo ========================================
echo RUNTIME DEPENDENCIES FOUND:
echo ========================================

if exist "%dependenciesFile%" (
    for /f "usebackq tokens=1,2,3 delims=|" %%a in ("%dependenciesFile%") do (
        call :log_quiet "%%a| %%b| %%c"
    )
) else (
    call :log_info "No runtime dependencies found."
)

echo.
echo ========================================
echo ANALYSIS AND RECOMMENDATIONS:
echo ========================================

call :log_warning "IMPORTANT: Do NOT remove these without careful consideration!"
echo.

call :log_info "Visual C++ Redistributables:"
call :log_info "- Usually required by C++ applications"
call :log_info "- Multiple versions can coexist safely"
call :log_info "- Removing may break software"

echo.
call :log_info ".NET Runtimes:"
call :log_info "- Required by .NET applications"
call :log_info "- Check installed .NET apps before removing"
call :log_info "- Use 'dotnet --list-runtimes' for more details"

echo.
call :log_info "Other Dependencies:"
call :log_info "- DirectX: Usually required for games/graphics"
call :log_info "- EdgeWebView2: Required by many modern apps"
call :log_info "- OpenAL: Required for audio in some games"

echo.
echo ========================================
echo SAFETY CHECKS:
echo ========================================

call :log_info "To safely identify unused dependencies:"
echo.
echo "1. Check what applications you have installed:"
if exist "%applicationsFile%" (
    call :log_info "   Found these applications:"
    for /f "usebackq tokens=1,2 delims=|" %%a in ("%applicationsFile%") do (
        call :log_quiet "   - %%a"
    )
)

echo.
echo "2. Research each dependency before removal:"
call :log_info "   - Google the package ID to understand what uses it"
call :log_info "   - Check application requirements"
call :log_info "   - Create a system restore point first"

echo.
echo "3. Test removal in a safe environment first"

echo.
echo ========================================
echo MANUAL REMOVAL COMMANDS:
echo ========================================

echo.
echo ========================================================================================
echo. 
echo :::'###::::'########:'########:'########:'##::: ##:'########:'####::'#######::'##::: ##:
echo ::'## ##:::... ##..::... ##..:: ##.....:: ###:: ##:... ##..::. ##::'##.... ##: ###:: ##:
echo :'##:. ##::::: ##::::::: ##:::: ##::::::: ####: ##:::: ##::::: ##:: ##:::: ##: ####: ##:
echo '##:::. ##:::: ##::::::: ##:::: ######::: ## ## ##:::: ##::::: ##:: ##:::: ##: ## ## ##:
echo  #########:::: ##::::::: ##:::: ##...:::: ##. ####:::: ##::::: ##:: ##:::: ##: ##. ####:
echo  ##.... ##:::: ##::::::: ##:::: ##::::::: ##:. ###:::: ##::::: ##:: ##:::: ##: ##:. ###:
echo  ##:::: ##:::: ##::::::: ##:::: ########: ##::. ##:::: ##::::'####:. #######:: ##::. ##:
echo ..:::::..:::::..::::::::..:::::........::..::::..:::::..:::::....:::.......:::..::::..::
echo.
echo       USE THESE COMMANDS SHOWN BELOW AT YOUR OWN RISK!
echo.
echo       The commands below will uninstall the listed dependencies
echo ========================================================================================
echo.

call :log_warning "USE THESE COMMANDS AT YOUR OWN RISK!"
echo.

if exist "%dependenciesFile%" (
    for /f "usebackq tokens=2 delims=|" %%a in ("%dependenciesFile%") do (
        set "pkgId=%%a"
        set "pkgId=!pkgId: =!"
        call :log_quiet "winget uninstall --id !pkgId! --verbose"
    )
)

echo.
call :log_info "Files saved to: %outputFolder%"
call :log_verbose "Script completed successfully."

endlocal
