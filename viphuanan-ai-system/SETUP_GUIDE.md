# Viphuanan Resort — AI Booking System Setup Guide

## Overview

ระบบนี้เชื่อมต่อ Claude AI กับ:
- **Ezee Absolute PMS** — จัดการการจองห้องพัก
- **Google Calendar** — ติดตามการจองในปฏิทิน
- **Google Sheets** — บันทึกข้อมูลการจองทั้งหมด

---

## ขั้นตอนการติดตั้ง

### 1. Clone โปรเจกต์

```bash
git clone https://github.com/innosenze88/auto_trade.git
cd auto_trade/viphuanan-ai-system
```

### 2. ติดตั้ง Python dependencies

```bash
pip install -r requirements.txt
```

### 3. ตั้งค่า Environment Variables

```bash
cp .env.example .env
# แก้ไขค่าใน .env ให้ถูกต้อง
```

แก้ไขไฟล์ `.env`:

| Variable | คำอธิบาย |
|---|---|
| `EZEE_API_KEY` | API Key จาก Ezee Absolute dashboard |
| `EZEE_HOTEL_CODE` | Hotel Code ใน Ezee |
| `GOOGLE_CREDENTIALS_FILE` | Path ไปยัง Google Service Account JSON |
| `GOOGLE_CALENDAR_ID` | Google Calendar ID สำหรับการจอง |
| `GOOGLE_SHEETS_ID` | ID ของ Google Spreadsheet |

### 4. ตั้งค่า Google Service Account

1. ไปที่ [Google Cloud Console](https://console.cloud.google.com)
2. สร้าง Service Account ใหม่
3. Enable APIs: **Google Calendar API**, **Google Sheets API**
4. Download credentials JSON → บันทึกเป็น `credentials.json`
5. Share Calendar และ Spreadsheet ให้ Service Account email

### 5. ตั้งค่า Claude Desktop

คัดลอก `claude_desktop_config.json` ไปยัง:

- **macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

แก้ไข `cwd` และ `env` ให้ตรงกับ path จริง แล้ว restart Claude Desktop

### 6. ทดสอบระบบ

```bash
# รัน unit tests
python -m pytest tests/ -v

# ทดสอบ MCP servers แบบ standalone
python mcp_servers/ezee_server.py
python mcp_servers/google_server.py
```

---

## โครงสร้าง Project

```
viphuanan-ai-system/
├── mcp_servers/
│   ├── ezee_server.py       # Ezee PMS MCP server
│   ├── google_server.py     # Google Calendar & Sheets MCP server
│   └── utils/
│       ├── __init__.py
│       └── helpers.py       # Shared utilities (date parsing, logging)
├── tests/
│   └── test_helpers.py      # Unit tests
├── .env.example             # Template สำหรับ environment variables
├── requirements.txt         # Python dependencies
├── claude_desktop_config.json  # Config สำหรับ Claude Desktop
└── SETUP_GUIDE.md           # คู่มือนี้
```

---

## การใช้งานกับ Claude

เมื่อ setup เสร็จแล้ว Claude จะสามารถ:

**ตรวจสอบห้องว่าง:**
> "เช็คห้องว่างสำหรับ 20-25 สิงหาคม 2025 สำหรับผู้ใหญ่ 2 คน"

**จองห้อง:**
> "จองห้อง Deluxe Ocean View สำหรับคุณสมชาย ใจดี อีเมล somchai@email.com เช็คอิน 20 สิงหาคม เช็คเอาท์ 25 สิงหาคม"

**บันทึกลงปฏิทิน:**
> "บันทึกการจองนี้ลงใน Google Calendar"

**ดูรายการจอง:**
> "แสดงการจองทั้งหมดในเดือนสิงหาคม"

---

## แก้ไขปัญหาที่พบบ่อย

| ปัญหา | วิธีแก้ |
|---|---|
| `EZEE_API_KEY not set` | ตรวจสอบไฟล์ `.env` |
| Google API 403 error | ตรวจสอบว่า Share Calendar/Sheet ให้ Service Account แล้ว |
| MCP server ไม่ connect | ตรวจสอบ `cwd` path ใน `claude_desktop_config.json` |
| Module not found | รัน `pip install -r requirements.txt` อีกครั้ง |
