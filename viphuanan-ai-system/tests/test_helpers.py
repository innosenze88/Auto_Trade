"""Unit tests for utility helpers."""

from datetime import date
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from mcp_servers.utils.helpers import format_date, parse_thai_date


def test_format_date_from_date_object():
    assert format_date(date(2025, 8, 15)) == "2025-08-15"


def test_format_date_from_string():
    assert format_date("2025-08-15") == "2025-08-15"


def test_parse_thai_date_valid():
    result = parse_thai_date("15 สิงหาคม 2568")
    assert result == date(2025, 8, 15)


def test_parse_thai_date_invalid_returns_none():
    assert parse_thai_date("ไม่ถูกต้อง") is None


def test_parse_thai_date_all_months():
    months = {
        "มกราคม": 1, "กุมภาพันธ์": 2, "มีนาคม": 3, "เมษายน": 4,
        "พฤษภาคม": 5, "มิถุนายน": 6, "กรกฎาคม": 7, "สิงหาคม": 8,
        "กันยายน": 9, "ตุลาคม": 10, "พฤศจิกายน": 11, "ธันวาคม": 12,
    }
    for name_th, month_num in months.items():
        result = parse_thai_date(f"1 {name_th} 2568")
        assert result is not None and result.month == month_num
