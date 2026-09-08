@echo off
echo ========================================
echo  Viphuanan AI System - Auto Setup
echo ========================================
echo.

:: ตรวจสอบ Python
python --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] ไม่พบ Python - ดาวน์โหลดที่ https://python.org
    pause
    exit /b 1
)
echo [OK] Python พร้อมใช้งาน

:: ตรวจสอบ pip
pip --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] ไม่พบ pip
    pause
    exit /b 1
)
echo [OK] pip พร้อมใช้งาน

:: ติดตั้ง dependencies
echo.
echo กำลังติดตั้ง dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo [ERROR] ติดตั้ง dependencies ไม่สำเร็จ
    pause
    exit /b 1
)
echo [OK] ติดตั้ง dependencies เสร็จแล้ว

:: สร้างไฟล์ .env
echo.
if not exist .env (
    copy .env.example .env
    echo [OK] สร้างไฟล์ .env แล้ว
    echo.
    echo *** กรุณาแก้ไขไฟล์ .env ใส่ API keys ของคุณ ***
    notepad .env
) else (
    echo [OK] ไฟล์ .env มีอยู่แล้ว
)

:: รัน tests
echo.
echo กำลังรัน tests...
python -m pytest tests/ -v
if errorlevel 1 (
    echo [WARN] บาง tests ไม่ผ่าน
) else (
    echo [OK] Tests ผ่านทั้งหมด
)

echo.
echo ========================================
echo  Setup เสร็จสมบูรณ์!
echo ========================================
echo.
echo ขั้นตอนต่อไป:
echo 1. กรอก API keys ใน .env (ถ้ายังไม่ได้ทำ)
echo 2. Copy claude_desktop_config.json ไปที่:
echo    %%APPDATA%%\Claude\claude_desktop_config.json
echo 3. Restart Claude Desktop
echo.
pause
