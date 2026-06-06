@echo off
:: Check for administrative privileges
net session >nul 2>&1
if %errorLevel% == 0 (
    goto :admin
) else (
    echo Requesting administrative privileges...
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    exit /b
)

:admin
echo Installing Alitken Converter to SendTo Menu...

:: Get the current directory of this script (without trailing backslash)
set "DIR=%~dp0"
set "DIR=%DIR:~0,-1%"

:: The target batch file
set "TARGET_BAT=%DIR%\Alit Converter.bat"

:: Check if the target batch file exists in the same directory
if not exist "%TARGET_BAT%" (
    echo ERROR: Cannot find "%TARGET_BAT%"
    echo Please ensure this install script is in the same folder as "Alit Converter.bat".
    pause
    exit /b
)

:: Create SendTo Shortcut using PowerShell
set "SHORTCUT_PATH=%APPDATA%\Microsoft\Windows\SendTo\Alitken Converter.lnk"
echo Creating shortcut at "%SHORTCUT_PATH%"...
powershell -Command "$WshShell = New-Object -ComObject WScript.Shell; $Shortcut = $WshShell.CreateShortcut('%SHORTCUT_PATH%'); $Shortcut.TargetPath = '%TARGET_BAT%'; $Shortcut.WorkingDirectory = '%DIR%'; $Shortcut.Save()"

:: Clean up old registry-based context menu if it exists
reg delete "HKCR\*\shell\AlitkenConverter" /f >nul 2>&1

echo.
echo Installation complete! 
echo You can now select files, right-click, choose "Send to" -> "Alitken Converter".
echo.
pause

