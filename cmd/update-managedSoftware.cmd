@echo off
REM  ************************************************************
REM  * @author scpg
REM  * @version 1.1
REM  * @date 2025-08-07
REM  * @license "MIT License" https://opensource.org/licenses/MIT
REM  *
REM  * Update all winget managed software with verbosity support
REM  * Usage: update-managedSoftware.cmd [-v|--verbose] [-q|--quiet] [-h|--help]
REM  ************************************************************
setlocal

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
echo %*
goto :eof

:skip_functions

call :log_verbose "Starting winget software list generation..."

REM get date and time
call :log_verbose "Getting current date and time..."
For /f "tokens=1-3 delims=/ " %%a in ('date /t') do (set myDate=%%c%%a%%b)
For /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set myTime=%%a%%b)
call :log_verbose "Date: %myDate%, Time: %myTime%"

set "timeStamp=%myDate%-%myTime%"
set "scriptName=%~n0"
set "outputFolder=%TEMP%\%scriptName%_%timeStamp%_%random%"
call :log_verbose "Date: %myDate%, Time: %myTime%"
call :log_verbose "timeStamp: %timeStamp%"
call :log_verbose "scriptName: %scriptName%"
call :log_verbose "outputFolder: %outputFolder%"


call :log_verbose "Creating output folder: %outputFolder%"
mkdir "%outputFolder%" || (
    call :log_error "Failed to create output folder '%outputFolder%'"
    exit /b 1
)

REM Create a file with just the IDs
set "idsFile=%outputFolder%\package-ids.txt"

call :log_verbose "Running winget list command..."
rem Run the command and capture the output
winget list --upgrade-available --source=winget --disable-interactivity > "%outputFolder%\winget-list.txt"

call :log_verbose "Extracting package IDs from winget output..."
REM Skip first 2 lines and extract the Id column using PowerShell for robust parsing
powershell -Command "Get-Content '%outputFolder%\winget-list.txt' | Select-Object -Skip 2 | ForEach-Object { if ($_ -match '^\s*(.+?)\s+(\S+)\s+(\S+)\s+(\S+)\s*$' -and $matches[2] -ne 'Id' -and $matches[2] -notmatch '^-+$' -and $matches[2] -notmatch '^<$' -and $_ -notmatch 'upgrades available') { $matches[2] } } | Where-Object { $_ -ne '' }" > "%idsFile%"

call :log_verbose "Package IDs saved to: %idsFile%"

if %VERBOSE% geq 1 (
    echo.
    echo Contents of package IDs file:
    echo =============================
)

for /f "usebackq delims=" %%a in ("%idsFile%") do (
    call :log_info "Package ID: %%a"
    if %VERBOSE% geq 1 (
        winget upgrade --id %%a --verbose --disable-interactivity
    )else (
        winget upgrade --id %%a --disable-interactivity
    )

    rem winget upgrade --id %%a --verbose --disable-interactivity
)

call :log_verbose "Script completed successfully."

endlocal