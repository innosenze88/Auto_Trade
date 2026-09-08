"""MCP Server — Ezee Absolute PMS integration for Viphuanan Resort."""

import os
import asyncio
from datetime import date
from typing import Any

import httpx
from dotenv import load_dotenv
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

load_dotenv()

API_KEY = os.getenv("EZEE_API_KEY", "")
HOTEL_CODE = os.getenv("EZEE_HOTEL_CODE", "")
BASE_URL = os.getenv("EZEE_BASE_URL", "https://live.ipms247.com/booking/reservation_request.php")

server = Server("ezee-pms")


def _base_params() -> dict:
    return {"APIKey": API_KEY, "HotelCode": HOTEL_CODE, "ResponseType": "JSON"}


@server.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="check_availability",
            description="Check room availability for given dates and room type at Viphuanan Resort.",
            inputSchema={
                "type": "object",
                "properties": {
                    "checkin_date": {"type": "string", "description": "Check-in date YYYY-MM-DD"},
                    "checkout_date": {"type": "string", "description": "Check-out date YYYY-MM-DD"},
                    "room_type_code": {"type": "string", "description": "Ezee room type code (optional)"},
                    "adults": {"type": "integer", "description": "Number of adults", "default": 2},
                },
                "required": ["checkin_date", "checkout_date"],
            },
        ),
        Tool(
            name="create_reservation",
            description="Create a new hotel reservation in Ezee PMS.",
            inputSchema={
                "type": "object",
                "properties": {
                    "checkin_date": {"type": "string", "description": "Check-in date YYYY-MM-DD"},
                    "checkout_date": {"type": "string", "description": "Check-out date YYYY-MM-DD"},
                    "room_type_code": {"type": "string", "description": "Ezee room type code"},
                    "guest_name": {"type": "string", "description": "Full name of the guest"},
                    "guest_email": {"type": "string", "description": "Guest email address"},
                    "guest_phone": {"type": "string", "description": "Guest phone number"},
                    "adults": {"type": "integer", "default": 2},
                    "children": {"type": "integer", "default": 0},
                    "special_requests": {"type": "string", "description": "Special requests or notes"},
                },
                "required": ["checkin_date", "checkout_date", "room_type_code", "guest_name", "guest_email"],
            },
        ),
        Tool(
            name="get_reservation",
            description="Retrieve an existing reservation by confirmation number.",
            inputSchema={
                "type": "object",
                "properties": {
                    "confirmation_number": {"type": "string", "description": "Ezee reservation confirmation number"},
                },
                "required": ["confirmation_number"],
            },
        ),
        Tool(
            name="cancel_reservation",
            description="Cancel a reservation by confirmation number.",
            inputSchema={
                "type": "object",
                "properties": {
                    "confirmation_number": {"type": "string"},
                    "reason": {"type": "string", "description": "Cancellation reason"},
                },
                "required": ["confirmation_number"],
            },
        ),
        Tool(
            name="list_room_types",
            description="List all available room types at Viphuanan Resort.",
            inputSchema={"type": "object", "properties": {}},
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict[str, Any]) -> list[TextContent]:
    async with httpx.AsyncClient(timeout=30) as client:
        if name == "check_availability":
            params = {
                **_base_params(),
                "Request": "CheckAvailability",
                "ArrivalDate": arguments["checkin_date"],
                "DepartureDate": arguments["checkout_date"],
                "Adults": arguments.get("adults", 2),
            }
            if arguments.get("room_type_code"):
                params["RoomTypeCode"] = arguments["room_type_code"]
            resp = await client.get(BASE_URL, params=params)
            return [TextContent(type="text", text=resp.text)]

        elif name == "create_reservation":
            params = {
                **_base_params(),
                "Request": "CreateReservation",
                "ArrivalDate": arguments["checkin_date"],
                "DepartureDate": arguments["checkout_date"],
                "RoomTypeCode": arguments["room_type_code"],
                "GuestName": arguments["guest_name"],
                "GuestEmail": arguments["guest_email"],
                "GuestPhone": arguments.get("guest_phone", ""),
                "Adults": arguments.get("adults", 2),
                "Children": arguments.get("children", 0),
                "SpecialRequest": arguments.get("special_requests", ""),
            }
            resp = await client.post(BASE_URL, data=params)
            return [TextContent(type="text", text=resp.text)]

        elif name == "get_reservation":
            params = {
                **_base_params(),
                "Request": "GetReservation",
                "ConfirmationNumber": arguments["confirmation_number"],
            }
            resp = await client.get(BASE_URL, params=params)
            return [TextContent(type="text", text=resp.text)]

        elif name == "cancel_reservation":
            params = {
                **_base_params(),
                "Request": "CancelReservation",
                "ConfirmationNumber": arguments["confirmation_number"],
                "CancellationReason": arguments.get("reason", "Guest request"),
            }
            resp = await client.post(BASE_URL, data=params)
            return [TextContent(type="text", text=resp.text)]

        elif name == "list_room_types":
            params = {**_base_params(), "Request": "GetRoomTypes"}
            resp = await client.get(BASE_URL, params=params)
            return [TextContent(type="text", text=resp.text)]

        else:
            return [TextContent(type="text", text=f"Unknown tool: {name}")]


async def main() -> None:
    async with stdio_server() as (read_stream, write_stream):
        await server.run(read_stream, write_stream, server.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
