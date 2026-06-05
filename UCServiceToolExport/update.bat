@echo off
setlocal enabledelayedexpansion

rem เปิดใช้งาน ANSI Escape Codes สำหรับแสดงสี
for /F "tokens=1,2 delims=#" %%a in ('"prompt #$H#$E# & echo on & for %%b in (1) do rem"') do set "ESC=%%b"
set "C_CYAN=%ESC%[96m"
set "C_GREEN=%ESC%[92m"
set "C_YELLOW=%ESC%[93m"
set "C_RED=%ESC%[91m"
set "C_RESET=%ESC%[0m"

set "EXE_NAME=UCServiceToolExport.exe"
set "TARGET_DIR="

echo %C_CYAN%===================================================%C_RESET%
echo %C_CYAN%[1/5] Detecting application path%C_RESET%
echo %C_CYAN%===================================================%C_RESET%

rem --- ระดับที่ 1: ตรวจสอบจากโปรแกรมที่กำลังรันอยู่ ---
for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "(Get-Process -Name 'UCServiceToolExport' -ErrorAction SilentlyContinue).Path | Split-Path -Parent"`) do (
    set "TARGET_DIR=%%i"
)

rem --- ระดับที่ 2: แผนสำรอง ถ้าโปรแกรมไม่ได้รันอยู่ ให้เช็กในโฟลเดอร์ตัวเอง ---
if "%TARGET_DIR%"=="" (
    echo %C_YELLOW%Application is not running. Checking local directory...%C_RESET%
    if exist "%~dp0%EXE_NAME%" (
        rem ดึง Path ของโฟลเดอร์ปัจจุบันแบบไม่มีเครื่องหมาย \ ปิดท้าย เพื่อไม่ให้ Path เพี้ยน
        set "TARGET_DIR=%~dp0"
        if "!TARGET_DIR:~-1!"=="\" set "TARGET_DIR=!TARGET_DIR:~0,-1!"
        echo %C_GREEN%Found %EXE_NAME% in current script folder.%C_RESET%
    )
)

rem --- หากตรวจสอบทั้ง 2 ระดับแล้วยังไม่เจอพิกัดโปรแกรม (ค้างหน้าจอให้ผู้ใช้กดปิดเอง) ---
if "%TARGET_DIR%"=="" (
    echo.
    echo %C_RED%===========================================================%C_RESET%
    echo %C_RED% ERROR: Cannot find UCServiceToolExport.exe path to update^!%C_RESET%
    echo %C_RED%===========================================================%C_RESET%
    echo %C_YELLOW%Please follow one of these instructions:%C_RESET%
    echo  1. Open '%EXE_NAME%' first so this updater can locate it.
    echo  2. Move this 'update.bat' into the same folder as '%EXE_NAME%'.
    echo.
    echo -----------------------------------------------------------
    echo Press any key to close this window...
    pause > nul
    exit /b
)

echo %C_GREEN%Target Path Locked:%C_RESET% !TARGET_DIR!

echo.
echo %C_CYAN%===================================================%C_RESET%
echo %C_CYAN%[2/5] Checking and closing application%C_RESET%
echo %C_CYAN%===================================================%C_RESET%
tasklist /FI "IMAGENAME eq %EXE_NAME%" 2>NUL | find /I /N "%EXE_NAME%">NUL
if "%ERRORLEVEL%"=="0" (
    echo %C_YELLOW%Closing %EXE_NAME% to unlock files...%C_RESET%
    taskkill /f /im %EXE_NAME% >nul 2>&1
    timeout /t 2 /nobreak > nul
) else (
    echo %EXE_NAME% is already closed. Proceeding...
)

echo.
echo %C_CYAN%===================================================%C_RESET%
echo %C_CYAN%[3/5] Preparing destination directories%C_RESET%
echo %C_CYAN%===================================================%C_RESET%
if not exist "!TARGET_DIR!\Script" (
    mkdir "!TARGET_DIR!\Script"
    echo %C_GREEN%Directory \Script\ created successfully.%C_RESET%
) else (
    echo Directory \Script\ already exists.
)

echo.
echo %C_CYAN%===================================================%C_RESET%
echo %C_CYAN%[4/5] Downloading files (Progress shown below)%C_RESET%
echo %C_CYAN%===================================================%C_RESET%
echo Downloading: %C_CYAN%forms.xml%C_RESET%
curl -L -# "https://raw.githubusercontent.com/inforeportable/UCServiceToolExport/refs/heads/main/UCServiceToolExport/forms.xml" -o "!TARGET_DIR!\forms.xml"
if %ERRORLEVEL% NEQ 0 (
    echo %C_RED%Error: Failed to download forms.xml%C_RESET%
    pause
    exit /b
)

echo.
echo Downloading: %C_CYAN%script.dcu%C_RESET%
curl -L -# "https://raw.githubusercontent.com/inforeportable/UCServiceToolExport/refs/heads/main/UCServiceToolExport/Script/script.dcu" -o "!TARGET_DIR!\Script\script.dcu"
if %ERRORLEVEL% NEQ 0 (
    echo %C_RED%Error: Failed to download script.dcu%C_RESET%
    pause
    exit /b
)

echo.
echo %C_CYAN%===================================================%C_RESET%
echo %C_CYAN%[5/5] Task completed. Restarting application%C_RESET%
echo %C_CYAN%===================================================%C_RESET%
echo %C_GREEN%All files updated successfully^! Restarting app in 3 seconds...%C_RESET%
timeout /t 3 /nobreak > nul

rem สั่งเปิดโปรแกรมกลับขึ้นมาจากพิกัดเป้าหมายที่กำหนดไว้
if exist "!TARGET_DIR!\%EXE_NAME%" (
    start "" "!TARGET_DIR!\%EXE_NAME%"
) else (
    echo %C_RED%[Warning] Cannot find %EXE_NAME% at the target path.%C_RESET%
    pause
)

exit