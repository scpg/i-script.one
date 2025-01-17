@echo off
REM  ************************************************************
REM  * @author scpg
REM  * @version 1.0
REM  * @date 2025-01-17
REM  * @license "MIT License" https://opensource.org/licenses/MIT
REM  *
REM  * List all winget managed software
REM  ************************************************************
setlocal

REM get date and time
For /f "tokens=1-3 delims=/ " %%a in ('date /t') do (set myDate=%%c%%a%%b)
For /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set myTime=%%a%%b)

set "timeStamp=%myDate%-%myTime%"
set "scriptName=%~n0"
set "outputFolder=%TEMP%\%scriptName%_%timeStamp%_%random%"
mkdir "%outputFolder%" || (
    echo Failed to create output folder "%outputFolder%"
    exit /b 1
)

rem Run the command and capture the output
winget list --upgrade-available --source=winget --disable-interactivity > "%outputFolder%\winget-list.txt"

type "%outputFolder%\winget-list.txt"

endlocal