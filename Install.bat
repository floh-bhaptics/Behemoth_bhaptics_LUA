@echo off
setlocal EnableDelayedExpansion

echo ================================================
echo  BehemothHaptics - bHaptics Mod Installer
echo ================================================
echo.

:: ── Locate the game ──────────────────────────────────────────────────────────

set "GAME_DIR="

:: Try the default Steam library location first
for %%D in (C D E F G H I) do (
    if exist "%%D:\SteamLibrary\steamapps\common\Skydance's BEHEMOTH\BHM\Binaries\Win64\BHM-Win64-Shipping.exe" (
        set "GAME_DIR=%%D:\SteamLibrary\steamapps\common\Skydance's BEHEMOTH\BHM\Binaries\Win64"
    )
)

:: If not found, ask the user
if not defined GAME_DIR (
    echo Could not find the game automatically.
    echo Please enter the full path to the game's Win64 folder.
    echo Example: C:\SteamLibrary\steamapps\common\Skydance's BEHEMOTH\BHM\Binaries\Win64
    echo.
    set /p "GAME_DIR=Path: "
)

if not exist "%GAME_DIR%\BHM-Win64-Shipping.exe" (
    echo ERROR: BHM-Win64-Shipping.exe not found in:
    echo   %GAME_DIR%
    echo Please re-run the installer and enter the correct path.
    pause
    exit /b 1
)

echo Game found at:
echo   %GAME_DIR%
echo.

:: ── Check UE4SS is installed ──────────────────────────────────────────────────

if not exist "%GAME_DIR%\dwmapi.dll" (
    echo ERROR: UE4SS does not appear to be installed.
    echo Please install UE4SS first:
    echo   1. Download UE4SS from https://github.com/UE4SS-RE/RE-UE4SS/releases
    echo   2. Extract the zip into:
    echo      %GAME_DIR%
    echo.
    pause
    exit /b 1
)

echo UE4SS detected.
echo.

:: ── Copy mod files ────────────────────────────────────────────────────────────

set "MOD_DIR=%GAME_DIR%\Mods\BehemothHaptics\scripts"

echo Installing mod files to:
echo   %MOD_DIR%
echo.

if not exist "%MOD_DIR%" mkdir "%MOD_DIR%"

copy /Y "%~dp0scripts\main.lua"            "%MOD_DIR%\" > nul
copy /Y "%~dp0scripts\bhaptics_library.dll" "%MOD_DIR%\" > nul
copy /Y "%~dp0scripts\bhaptics_wrapper.dll" "%MOD_DIR%\" > nul

echo Mod files copied.
echo.

:: ── Update mods.txt ───────────────────────────────────────────────────────────

set "MODS_TXT=%GAME_DIR%\Mods\mods.txt"
set "MOD_ENTRY=BehemothHaptics : 1"

if not exist "%MODS_TXT%" (
    echo Creating mods.txt...
    echo BehemothHaptics : ^1> "%MODS_TXT%"
    echo Done.
) else (
    :: Check if the entry already exists (enabled or disabled)
    findstr /i /c:"BehemothHaptics" "%MODS_TXT%" > nul
    if !errorlevel! == 0 (
        :: Entry exists — already present, nothing to do
        echo mods.txt: BehemothHaptics entry already present ^(enabled^).
    ) else (
        :: Append entry at the end of the file
        echo BehemothHaptics : ^1>> "%MODS_TXT%"
        echo mods.txt: BehemothHaptics entry added.
    )
)

echo.
echo ================================================
echo  Installation complete!
echo  Launch the game and listen for the heartbeat.
echo ================================================
echo.
pause
