# Viphuanan Resort — AI Booking System

ระบบ AI สำหรับจัดการการจองห้องพักโรงแรม เชื่อมต่อ Claude AI กับ Ezee Absolute PMS, Google Calendar และ Google Sheets ผ่าน MCP (Model Context Protocol)

---

## ภาพรวมระบบ

```
┌─────────────────────────────────────────────────────────┐
│                      Claude AI                          │
│              (ผู้ใช้พูดคุยภาษาไทย/อังกฤษ)              │
└───────────────────────┬─────────────────────────────────┘
                        │ MCP Protocol
          ┌─────────────┴─────────────┐
          │                           │
┌─────────▼──────────┐   ┌────────────▼────────────┐
│   ezee_server.py   │   │   google_server.py       │
│  (Ezee Absolute    │   │  (Google Calendar +      │
│      PMS)          │   │   Google Sheets)         │
└─────────┬──────────┘   └────────────┬────────────┘
          │                           │
┌─────────▼──────────┐   ┌────────────▼────────────┐
│  Ezee PMS API      │   │  Google APIs             │
│  (ระบบจองจริง)     │   │  (ปฏิทิน + สเปรดชีต)    │
└────────────────────┘   └─────────────────────────┘
```

Claude รับคำสั่งจากผู้ใช้ แล้วเรียก MCP servers ที่เหมาะสมโดยอัตโนมัติ ผู้ใช้ไม่ต้องรู้วิธีใช้ API เลย

---

## ความสามารถของระบบ

### 1. ตรวจสอบห้องว่าง
Claude เช็คห้องว่างจาก Ezee PMS แบบ real-time

**ตัวอย่างคำสั่ง:**
> "เช็คห้องว่างวันที่ 20-25 สิงหาคม สำหรับผู้ใหญ่ 2 คน"
> "มีห้อง Deluxe ว่างสัปดาห์หน้าไหม"

### 2. สร้างการจอง
สร้าง reservation ใน Ezee PMS พร้อมข้อมูลแขกครบถ้วน

**ตัวอย่างคำสั่ง:**
> "จองห้อง Deluxe Ocean View ให้คุณสมชาย ใจดี อีเมล somchai@gmail.com เบอร์ 0812345678 เช็คอิน 20 ส.ค. เช็คเอาท์ 25 ส.ค."

### 3. ดูรายละเอียดการจอง
ค้นหาการจองเดิมด้วยเลข confirmation

**ตัวอย่างคำสั่ง:**
> "ดูการจองหมายเลข VIP-2025-001"

### 4. ยกเลิกการจอง
ยกเลิก reservation พร้อมระบุเหตุผล

**ตัวอย่างคำสั่ง:**
> "ยกเลิกการจองหมายเลข VIP-2025-001 เนื่องจากแขกเปลี่ยนแผน"

### 5. บันทึกลง Google Calendar
เพิ่ม event การจองเข้าปฏิทินโดยอัตโนมัติ

**ตัวอย่างคำสั่ง:**
> "บันทึกการจองนี้ลงใน Google Calendar ด้วย"

### 6. ดูตารางการจองในปฏิทิน
ดูภาพรวมการจองของช่วงเวลาใดก็ได้

**ตัวอย่างคำสั่ง:**
> "แสดงการจองทั้งหมดในเดือนกันยายน"

### 7. บันทึกลง Google Sheets
เก็บประวัติการจองทั้งหมดในสเปรดชีต

**ตัวอย่างคำสั่ง:**
> "บันทึกข้อมูลแขกคนนี้ลงในชีตด้วย"

### 8. ดูรายการจองจากชีต
ดึงข้อมูลจาก Google Sheets เพื่อรายงานหรือวิเคราะห์

**ตัวอย่างคำสั่ง:**
> "ดูรายการจองทั้งหมดในชีต"

---

## โครงสร้างไฟล์

```
viphuanan-ai-system/
│
├── mcp_servers/                    # MCP Server files
│   ├── __init__.py
│   ├── ezee_server.py              # เชื่อมต่อ Ezee Absolute PMS
│   ├── google_server.py            # เชื่อมต่อ Google Calendar & Sheets
│   └── utils/
│       ├── __init__.py
│       └── helpers.py              # ฟังก์ชันช่วยเหลือ (แปลงวันที่, logging)
│
├── tests/
│   └── test_helpers.py             # Unit tests
│
├── .env.example                    # Template สำหรับ API keys
├── .gitignore
├── claude_desktop_config.json      # Config สำหรับ Claude Desktop
├── requirements.txt                # Python dependencies
├── SETUP_GUIDE.md                  # คู่มือติดตั้งละเอียด
└── README.md                       # ไฟล์นี้
```

---

## MCP Servers — รายละเอียด

### `ezee_server.py` — Ezee PMS

เชื่อมต่อกับ Ezee Absolute Hotel Management System

| Tool | หน้าที่ | Parameters หลัก |
|---|---|---|
| `check_availability` | เช็คห้องว่าง | checkin_date, checkout_date, room_type_code, adults |
| `create_reservation` | สร้างการจอง | checkin_date, checkout_date, room_type_code, guest_name, guest_email |
| `get_reservation` | ดูการจอง | confirmation_number |
| `cancel_reservation` | ยกเลิกการจอง | confirmation_number, reason |
| `list_room_types` | ดูประเภทห้องทั้งหมด | — |

**การทำงาน:** ส่ง HTTP request ไปยัง Ezee API endpoint พร้อม API Key และ Hotel Code แล้วส่งผลลัพธ์ JSON กลับให้ Claude แปลผลให้ผู้ใช้

---

### `google_server.py` — Google Services

เชื่อมต่อกับ Google Calendar และ Google Sheets ผ่าน Service Account

| Tool | หน้าที่ | Parameters หลัก |
|---|---|---|
| `add_booking_to_calendar` | เพิ่ม event ในปฏิทิน | guest_name, room_type, checkin_date, checkout_date |
| `list_calendar_events` | ดู event ในช่วงวันที่ | start_date, end_date |
| `log_booking_to_sheet` | บันทึกแถวใหม่ในชีต | confirmation_number, guest_name, room_type, checkin_date, checkout_date |
| `get_bookings_from_sheet` | ดึงข้อมูลจากชีต | sheet_range |

**การทำงาน:** ใช้ Google Service Account ที่มีสิทธิ์ Calendar + Sheets แล้วเรียก Google APIs ผ่าน `google-api-python-client`

---

### `utils/helpers.py` — ฟังก์ชันช่วยเหลือ

| ฟังก์ชัน | หน้าที่ |
|---|---|
| `format_date(d, fmt)` | แปลง date object หรือ string เป็น format ที่กำหนด |
| `parse_thai_date(text)` | แปลงวันภาษาไทย เช่น "15 สิงหาคม 2568" → `date(2025, 8, 15)` |
| `log_request(tool, params)` | บันทึก log ทุกครั้งที่มีการเรียก tool |

รองรับปี พ.ศ. → ค.ศ. อัตโนมัติ (ลบ 543) และรองรับชื่อเดือนภาษาไทยทั้ง 12 เดือน

---

## วิธีติดตั้ง (สรุปสั้น)

```bash
# 1. Clone
git clone https://github.com/innosenze88/Auto_Trade.git
cd Auto_Trade/viphuanan-ai-system

# 2. ติดตั้ง dependencies
pip install -r requirements.txt

# 3. ตั้งค่า environment
copy .env.example .env
notepad .env   # กรอก API keys

# 4. ทดสอบ
python -m pytest tests/ -v

# 5. Copy config ไปยัง Claude Desktop
# macOS: ~/Library/Application Support/Claude/claude_desktop_config.json
# Windows: %APPDATA%\Claude\claude_desktop_config.json
```

ดูรายละเอียดเต็มใน [SETUP_GUIDE.md](SETUP_GUIDE.md)

---

## สิ่งที่ต้องเตรียมก่อนใช้งาน

### Ezee Absolute PMS
- [ ] มี account ใน Ezee Absolute
- [ ] ขอ API Key จาก Ezee dashboard (Settings → API)
- [ ] จด Hotel Code ของโรงแรม

### Google Service Account
- [ ] สร้าง project ใน [Google Cloud Console](https://console.cloud.google.com)
- [ ] เปิดใช้งาน Google Calendar API และ Google Sheets API
- [ ] สร้าง Service Account และ download credentials.json
- [ ] Share Google Calendar ให้ email ของ Service Account
- [ ] Share Google Spreadsheet ให้ email ของ Service Account

### Claude Desktop
- [ ] ติดตั้ง [Claude Desktop](https://claude.ai/download)
- [ ] วาง `claude_desktop_config.json` ใน config folder
- [ ] Restart Claude Desktop

---

## Dependencies

| Package | เวอร์ชัน | หน้าที่ |
|---|---|---|
| `mcp` | ≥1.0.0 | MCP Protocol framework |
| `httpx` | ≥0.27.0 | HTTP client สำหรับ Ezee API |
| `google-api-python-client` | ≥2.100.0 | Google APIs |
| `google-auth-oauthlib` | ≥1.2.0 | Google authentication |
| `python-dotenv` | ≥1.0.0 | อ่านไฟล์ .env |
| `pydantic` | ≥2.0.0 | Data validation |
| `anyio` | ≥4.0.0 | Async I/O |

---

## แก้ไขปัญหาที่พบบ่อย

| ข้อผิดพลาด | สาเหตุ | วิธีแก้ |
|---|---|---|
| `EZEE_API_KEY not set` | ไม่ได้กรอก .env | ตรวจสอบไฟล์ .env |
| `Google 403 Forbidden` | Service Account ไม่มีสิทธิ์ | Share Calendar/Sheet ให้ Service Account email |
| `FileNotFoundError: credentials.json` | Path ไม่ถูกต้อง | ตรวจสอบ `GOOGLE_CREDENTIALS_FILE` ใน .env |
| MCP server ไม่ขึ้นใน Claude | Config ผิด | ตรวจสอบ `cwd` path ใน claude_desktop_config.json |
| `ModuleNotFoundError` | ยังไม่ได้ install | รัน `pip install -r requirements.txt` |

---

## License

สร้างสำหรับ Viphuanan Resort — ใช้ภายในองค์กร
