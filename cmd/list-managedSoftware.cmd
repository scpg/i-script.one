@echo off
REM  ************************************************************
REM  * @author scpg
REM  * @version 1.3
REM  * @date 2026-05-19
REM  * @license "MIT License" https://opensource.org/licenses/MIT
REM  *
REM  * List all winget managed software with verbosity and pattern filter support
REM  * Usage: list-managedSoftware.cmd [-v|--verbose] [-q|--quiet] [-p <pattern>] [-h|--help]
REM  ************************************************************
setlocal

REM Capture script name before any shift operations alter %0
set "scriptName=%~n0"
set "scriptNameFull=%~nx0"

REM Set default verbosity level (0=quiet, 1=normal, 2=verbose)
set VERBOSE=1

REM Set default pattern (empty = show all)
set PATTERN=

REM Parse command line arguments
:parse_args
if "%1"=="" goto :main
if /i "%1"=="-v" set VERBOSE=2 & shift & goto :parse_args
if /i "%1"=="--verbose" set VERBOSE=2 & shift & goto :parse_args
if /i "%1"=="-q" set VERBOSE=0 & shift & goto :parse_args
if /i "%1"=="--quiet" set VERBOSE=0 & shift & goto :parse_args
if /i "%1"=="-p" (
    if "%2"=="" (
        echo Error: -p requires a pattern argument.
        goto :show_help
    )
    set "PATTERN=%~2"
    shift & shift & goto :parse_args
)
if /i "%1"=="--pattern" (
    if "%2"=="" (
        echo Error: --pattern requires a pattern argument.
        goto :show_help
    )
    set "PATTERN=%~2"
    shift & shift & goto :parse_args
)
if /i "%1"=="-h" goto :show_help
if /i "%1"=="--help" goto :show_help
echo Unknown parameter: %1
goto :show_help

:show_help
echo Usage: %scriptNameFull% [options]
echo.
echo Options:
echo   -v, --verbose              Enable verbose output
echo   -q, --quiet                Quiet mode (minimal output)
echo   -p, --pattern ^<pattern^>  Filter results by package name or ID (case-insensitive)
echo   -h, --help                 Show this help message
echo.
echo Examples:
echo   %scriptNameFull%                       Run with normal output
echo   %scriptNameFull% -v                    Run with verbose output
echo   %scriptNameFull% --quiet               Run with minimal output
echo   %scriptNameFull% -p "Visual Studio"    Show only apps matching "Visual Studio"
echo   %scriptNameFull% -v -p git             Show verbose output filtered to "git"
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
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set myDate=%%i
for /f "tokens=*" %%i in ('powershell -NoProfile -Command "Get-Date -Format HHmm"') do set myTime=%%i
call :log_verbose "Date: %myDate%, Time: %myTime%"

set "timeStamp=%myDate%-%myTime%"
set "outputFolder=%TEMP%\%scriptName%_%timeStamp%_%random%"
call :log_verbose "timeStamp: %timeStamp%"
call :log_verbose "scriptName: %scriptName%"
call :log_verbose "outputFolder: %outputFolder%"

if defined PATTERN (
    call :log_verbose "Pattern filter: %PATTERN%"
) else (
    call :log_verbose "No pattern filter applied"
)

call :log_verbose "Creating output folder: %outputFolder%"
mkdir "%outputFolder%" || (
    call :log_error "Failed to create output folder '%outputFolder%'"
    exit /b 1
)

call :log_verbose "Running winget list command..."
winget list --upgrade-available --source=winget --disable-interactivity > "%outputFolder%\winget-list.txt"
call :log_verbose "Output saved to: %outputFolder%\winget-list.txt"

call :log_info "Displaying results:"

if defined PATTERN (
    findstr /i "%PATTERN%" "%outputFolder%\winget-list.txt"
) else (
    type "%outputFolder%\winget-list.txt"
)

call :log_verbose "Script completed successfully."

endlocal
