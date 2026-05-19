@echo off
REM  ************************************************************
REM  * @author scpg
REM  * @version 1.2
REM  * @date 2026-05-19
REM  * @license "MIT License" https://opensource.org/licenses/MIT
REM  *
REM  * Update all winget managed software with verbosity and pattern filter support
REM  * Usage: update-managedSoftware.cmd [-v|--verbose] [-q|--quiet] [-p <pattern>] [-h|--help]
REM  ************************************************************
setlocal

REM Capture script name before any shift operations alter %0
set "scriptName=%~n0"
set "scriptNameFull=%~nx0"

REM Set default verbosity level (0=quiet, 1=normal, 2=verbose)
set VERBOSE=1

REM Set default pattern (empty = update all)
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
echo   -p, --pattern ^<pattern^>  Only update packages matching name or ID (case-insensitive)
echo   -h, --help                 Show this help message
echo.
echo Examples:
echo   %scriptNameFull%                       Run with normal output
echo   %scriptNameFull% -v                    Run with verbose output
echo   %scriptNameFull% --quiet               Run with minimal output
echo   %scriptNameFull% -p "Visual Studio"    Update only apps matching "Visual Studio"
echo   %scriptNameFull% -p git                Update only packages matching "git"
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


call :log_verbose "Creating output folder: %outputFolder%"
mkdir "%outputFolder%" || (
    call :log_error "Failed to create output folder '%outputFolder%'"
    exit /b 1
)

set "idsFile=%outputFolder%\package-ids.txt"
set "pairsFile=%outputFolder%\name-id-pairs.txt"

call :log_verbose "Running winget list command..."
winget list --upgrade-available --source=winget --disable-interactivity > "%outputFolder%\winget-list.txt"

call :log_verbose "Extracting package Name/ID pairs from winget output..."
powershell -Command "Get-Content '%outputFolder%\winget-list.txt' | Select-Object -Skip 2 | ForEach-Object { if ($_ -match '^\s*(.+?)\s+(\S+)\s+(\S+)\s+(\S+)\s*$' -and $matches[2] -ne 'Id' -and $matches[2] -notmatch '^-+$' -and $matches[2] -notmatch '^<$' -and $_ -notmatch 'upgrades available') { $matches[1].Trim() + '|' + $matches[2] } } | Where-Object { $_ -ne '' }" > "%pairsFile%"

if defined PATTERN (
    call :log_verbose "Applying pattern filter: %PATTERN%"
    findstr /i "%PATTERN%" "%pairsFile%" > "%outputFolder%\filtered-pairs.txt"
    powershell -Command "Get-Content '%outputFolder%\filtered-pairs.txt' | ForEach-Object { $_.Split('|')[1] }" > "%idsFile%"
) else (
    powershell -Command "Get-Content '%pairsFile%' | ForEach-Object { $_.Split('|')[1] }" > "%idsFile%"
)

call :log_verbose "Package IDs saved to: %idsFile%"

if %VERBOSE% geq 1 (
    echo.
    echo Contents of package IDs file:
    echo =============================
)

for /f "usebackq delims=" %%a in ("%idsFile%") do (
    call :log_info "Package ID: %%a"
    if %VERBOSE% geq 1 (
        winget upgrade --id %%a --verbose --disable-interactivity --accept-package-agreements
    ) else (
        winget upgrade --id %%a --disable-interactivity --accept-package-agreements
    )
)

call :log_verbose "Script completed successfully."

endlocal