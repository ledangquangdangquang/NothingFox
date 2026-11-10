@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
title NothingFirefoxCss installer

rem ============================================================
rem  NothingFirefoxCss - Windows installer
rem
rem  Usage:
rem    install.bat                 interactive: choose a profile
rem    install.bat --all           install into every profile
rem    install.bat "C:\path\to\profile"
rem    install.bat --uninstall     remove the theme (choose a profile)
rem    install.bat --uninstall --all
rem ============================================================

set "SRC=%~dp0"
set "FF_ROOT=%APPDATA%\Mozilla\Firefox"
set "PROFILES_DIR=%FF_ROOT%\Profiles"
set "MODE=install"
set "ALL=0"
set "TARGET="

:parse_args
if "%~1"=="" goto args_done
if /i "%~1"=="--uninstall" ( set "MODE=uninstall" & shift & goto parse_args )
if /i "%~1"=="-u"          ( set "MODE=uninstall" & shift & goto parse_args )
if /i "%~1"=="--all"       ( set "ALL=1" & shift & goto parse_args )
if /i "%~1"=="-a"          ( set "ALL=1" & shift & goto parse_args )
if /i "%~1"=="--help"      goto usage
if /i "%~1"=="-h"          goto usage
if /i "%~1"=="/?"          goto usage
set "TARGET=%~f1"
shift
goto parse_args
:args_done

echo.
echo  =============================================
echo     NothingFirefoxCss - %MODE%
echo  =============================================
echo.

if "%MODE%"=="install" (
    if not exist "%SRC%userChrome.css" (
        echo [ERROR] userChrome.css not found next to this script: %SRC%
        goto fail
    )
)

rem ---------- warn if Firefox is running ----------
tasklist /FI "IMAGENAME eq firefox.exe" 2>nul | find /i "firefox.exe" >nul
if not errorlevel 1 if not defined NOPAUSE (
    echo [!] Firefox is running. Changes only take effect after a restart.
    choice /C YN /N /M "    Close Firefox now? [Y/N] "
    if !errorlevel! EQU 1 (
        taskkill /IM firefox.exe >nul 2>&1
        timeout /t 3 /nobreak >nul
        taskkill /F /IM firefox.exe >nul 2>&1
        set "RESTART=1"
    )
    echo.
)

rem ---------- explicit profile path ----------
if defined TARGET (
    if not exist "%TARGET%\prefs.js" if not exist "%TARGET%\times.json" (
        echo [ERROR] "%TARGET%" does not look like a Firefox profile.
        goto fail
    )
    call :do_%MODE% "%TARGET%"
    goto done
)

if not exist "%PROFILES_DIR%" (
    echo [ERROR] No Firefox profiles found in "%PROFILES_DIR%".
    echo         Start Firefox once to create a profile, then rerun this script.
    goto fail
)

rem ---------- find default profile from installs.ini ----------
set "DEFAULT_PROFILE="
if exist "%FF_ROOT%\installs.ini" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%FF_ROOT%\installs.ini") do (
        if /i "%%a"=="Default" if not defined DEFAULT_PROFILE set "DEFAULT_PROFILE=%%b"
    )
)
if defined DEFAULT_PROFILE set "DEFAULT_PROFILE=!DEFAULT_PROFILE:/=\!"

rem ---------- list profiles ----------
set /a COUNT=0
set "DEFAULT_INDEX="
for /d %%D in ("%PROFILES_DIR%\*") do (
    if exist "%%D\prefs.js" (
        set /a COUNT+=1
        set "PROFILE_!COUNT!=%%D"
        set "MARK="
        if /i "Profiles\%%~nxD"=="!DEFAULT_PROFILE!" (
            set "MARK=  (default)"
            set "DEFAULT_INDEX=!COUNT!"
        )
        echo   [!COUNT!] %%~nxD!MARK!
    )
)

if %COUNT% EQU 0 (
    echo [ERROR] No usable profile found in "%PROFILES_DIR%".
    goto fail
)
if not defined DEFAULT_INDEX set "DEFAULT_INDEX=1"

if "%ALL%"=="1" (
    for /l %%i in (1,1,%COUNT%) do call :do_%MODE% "!PROFILE_%%i!"
    goto done
)

echo   [A] All profiles
echo.
set "CHOICE_IN="
set /p "CHOICE_IN=Choose a profile [default: %DEFAULT_INDEX%]: "
if not defined CHOICE_IN set "CHOICE_IN=%DEFAULT_INDEX%"

if /i "%CHOICE_IN%"=="A" (
    for /l %%i in (1,1,%COUNT%) do call :do_%MODE% "!PROFILE_%%i!"
    goto done
)

set "SELECTED="
for /l %%i in (1,1,%COUNT%) do if "%CHOICE_IN%"=="%%i" set "SELECTED=!PROFILE_%%i!"
if not defined SELECTED (
    echo [ERROR] Invalid choice: %CHOICE_IN%
    goto fail
)
call :do_%MODE% "%SELECTED%"
goto done


rem ============================================================
:do_install
set "P=%~1"
set "CHROME=%P%\chrome"
echo.
echo  -^> Installing into: %P%

if exist "%CHROME%\userChrome.css" (
    for /f %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%t"
    set "BACKUP=%P%\chrome.backup-!STAMP!"
    xcopy "%CHROME%" "!BACKUP!\" /E /I /Q /Y >nul
    echo     Backed up existing chrome folder to: !BACKUP!
)

if not exist "%CHROME%" mkdir "%CHROME%"
copy /Y "%SRC%userChrome.css"  "%CHROME%\userChrome.css"  >nul || (echo     [ERROR] copy userChrome.css failed & exit /b 1)
if exist "%SRC%userContent.css" copy /Y "%SRC%userContent.css" "%CHROME%\userContent.css" >nul
echo     Copied userChrome.css, userContent.css

call :set_pref "%P%" "toolkit.legacyUserProfileCustomizations.stylesheets" "true"
call :set_pref "%P%" "browser.toolbars.bookmarks.visibility" "'always'"
echo     user.js prefs set
exit /b 0


rem ============================================================
:do_uninstall
set "P=%~1"
echo.
echo  -^> Uninstalling from: %P%
if exist "%P%\chrome\userChrome.css"  del /Q "%P%\chrome\userChrome.css"
if exist "%P%\chrome\userContent.css" del /Q "%P%\chrome\userContent.css"
echo     Removed userChrome.css, userContent.css
echo     (Backups chrome.backup-* are kept; copy one back into "chrome" to restore.)
exit /b 0


rem ============================================================
rem  :set_pref <profile> <pref name> <js value; use 'x' for strings>
rem  Removes any existing line for the pref in user.js, then appends the new one.
:set_pref
set "UJS=%~1\user.js"
set "PREF_NAME=%~2"
set "PREF_VALUE=%~3"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$env:UJS; $n=$env:PREF_NAME; $v=$env:PREF_VALUE.Replace([char]39,[char]34); $q=[char]34; $lines=@(); if (Test-Path -LiteralPath $f) { $lines=@(Get-Content -LiteralPath $f | Where-Object { $_ -notmatch ('user_pref\(\s*' + $q + [regex]::Escape($n) + $q) }) }; $lines += ('user_pref(' + $q + $n + $q + ', ' + $v + ');'); [IO.File]::WriteAllLines($f, [string[]]$lines)"
exit /b 0


rem ============================================================
:usage
echo Usage:
echo   install.bat                     choose a profile interactively
echo   install.bat --all               install into all profiles
echo   install.bat "C:\path\profile"   install into a specific profile
echo   install.bat --uninstall [--all]
exit /b 0

:done
echo.
echo  [OK] Done.
if defined RESTART (
    if exist "%ProgramFiles%\Mozilla Firefox\firefox.exe" (
        start "" "%ProgramFiles%\Mozilla Firefox\firefox.exe"
    ) else (
        start "" firefox.exe
    )
) else (
    echo  Restart Firefox to see the changes.
)
echo.
if not defined NOPAUSE pause
exit /b 0

:fail
echo.
if not defined NOPAUSE pause
exit /b 1
