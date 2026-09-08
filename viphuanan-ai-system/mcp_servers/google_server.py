"""MCP Server — Google Calendar & Sheets integration for Viphuanan Resort."""

import os
import asyncio
import json
from typing import Any

from dotenv import load_dotenv
from google.oauth2 import service_account
from googleapiclient.discovery import build
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

load_dotenv()

CREDENTIALS_FILE = os.getenv("GOOGLE_CREDENTIALS_FILE", "credentials.json")
CALENDAR_ID = os.getenv("GOOGLE_CALENDAR_ID", "")
SHEETS_ID = os.getenv("GOOGLE_SHEETS_ID", "")
HOTEL_TZ = os.getenv("HOTEL_TIMEZONE", "Asia/Bangkok")

SCOPES = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/spreadsheets",
]

server = Server("google-services")


def _get_credentials():
    return service_account.Credentials.from_service_account_file(CREDENTIALS_FILE, scopes=SCOPES)


def _calendar_service():
    return build("calendar", "v3", credentials=_get_credentials())


def _sheets_service():
    return build("sheets", "v4", credentials=_get_credentials())


@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="add_booking_to_calendar",
            description="Add a confirmed hotel reservation as a Google Calendar event.",
            inputSchema={
                "type": "object",
                "properties": {
                    "guest_name": {"type": "string"},
                    "room_type": {"type": "string"},
                    "checkin_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "checkout_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "confirmation_number": {"type": "string"},
                    "notes": {"type": "string"},
                },
                "required": ["guest_name", "room_type", "checkin_date", "checkout_date"],
            },
        ),
        Tool(
            name="list_calendar_events",
            description="List upcoming reservation events from Google Calendar.",
            inputSchema={
                "type": "object",
                "properties": {
                    "start_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "end_date": {"type": "string", "description": "YYYY-MM-DD"},
                    "max_results": {"type": "integer", "default": 20},
                },
                "required": ["start_date", "end_date"],
            },
        ),
        Tool(
            name="log_booking_to_sheet",
            description="Append a booking record to the Google Sheets booking log.",
            inputSchema={
                "type": "object",
                "properties": {
                    "confirmation_number": {"type": "string"},
                    "guest_name": {"type": "string"},
                    "guest_email": {"type": "string"},
                    "guest_phone": {"type": "string"},
                    "room_type": {"type": "string"},
                    "checkin_date": {"type": "string"},
                    "checkout_date": {"type": "string"},
                    "total_amount": {"type": "number"},
                    "status": {"type": "string", "description": "e.g. Confirmed, Cancelled"},
                    "notes": {"type": "string"},
                },
                "required": ["confirmation_number", "guest_name", "room_type", "checkin_date", "checkout_date"],
            },
        ),
        Tool(
            name="get_bookings_from_sheet",
            description="Query the Google Sheets booking log by date range or guest name.",
            inputSchema={
                "type": "object",
                "properties": {
                    "sheet_range": {"type": "string", "description": "Sheet range e.g. 'Bookings!A2:J100'", "default": "Bookings!A2:J200"},
                },
            },
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    if name == "add_booking_to_calendar":
        cal = _calendar_service()
        event = {
            "summary": f"[{arguments.get('confirmation_number', 'NEW')}] {arguments['guest_name']} — {arguments['room_type']}",
            "description": arguments.get("notes", ""),
            "start": {"date": arguments["checkin_date"], "timeZone": HOTEL_TZ},
            "end": {"date": arguments["checkout_date"], "timeZone": HOTEL_TZ},
        }
        result = cal.events().insert(calendarId=CALENDAR_ID, body=event).execute()
        return [TextContent(type="text", text=json.dumps(result, ensure_ascii=False))]

    elif name == "list_calendar_events":
        cal = _calendar_service()
        result = cal.events().list(
            calendarId=CALENDAR_ID,
            timeMin=f"{arguments['start_date']}T00:00:00+07:00",
            timeMax=f"{arguments['end_date']}T23:59:59+07:00",
            maxResults=arguments.get("max_results", 20),
            singleEvents=True,
            orderBy="startTime",
        ).execute()
        events = result.get("items", [])
        return [TextContent(type="text", text=json.dumps(events, ensure_ascii=False, indent=2))]

    elif name == "log_booking_to_sheet":
        sheets = _sheets_service()
        row = [
            arguments.get("confirmation_number", ""),
            arguments.get("guest_name", ""),
            arguments.get("guest_email", ""),
            arguments.get("guest_phone", ""),
            arguments.get("room_type", ""),
            arguments.get("checkin_date", ""),
            arguments.get("checkout_date", ""),
            arguments.get("total_amount", ""),
            arguments.get("status", "Confirmed"),
            arguments.get("notes", ""),
        ]
        body = {"values": [row]}
        result = sheets.spreadsheets().values().append(
            spreadsheetId=SHEETS_ID,
            range="Bookings!A:J",
            valueInputOption="USER_ENTERED",
            body=body,
        ).execute()
        return [TextContent(type="text", text=json.dumps(result, ensure_ascii=False))]

    elif name == "get_bookings_from_sheet":
        sheets = _sheets_service()
        range_ = arguments.get("sheet_range", "Bookings!A2:J200")
        result = sheets.spreadsheets().values().get(
            spreadsheetId=SHEETS_ID, range=range_
        ).execute()
        return [TextContent(type="text", text=json.dumps(result.get("values", []), ensure_ascii=False, indent=2))]

    else:
        return [TextContent(type="text", text=f"Unknown tool: {name}")]


async def main() -> None:
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
