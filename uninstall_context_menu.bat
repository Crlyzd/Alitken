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
echo Uninstalling Alitken Converter...

:: Delete the SendTo shortcut
set "SHORTCUT_PATH=%APPDATA%\Microsoft\Windows\SendTo\Alitken Converter.lnk"
if exist "%SHORTCUT_PATH%" (
    echo Deleting SendTo shortcut...
    del "%SHORTCUT_PATH%"
)

:: Delete the old registry key if it exists
reg delete "HKCR\*\shell\AlitkenConverter" /f >nul 2>&1

echo.
echo Uninstallation complete! The context menu option and SendTo shortcut have been removed.
pause

