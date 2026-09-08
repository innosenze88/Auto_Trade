from datetime import datetime, date
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger(__name__)

THAI_MONTHS = {
    "มกราคม": 1, "กุมภาพันธ์": 2, "มีนาคม": 3, "เมษายน": 4,
    "พฤษภาคม": 5, "มิถุนายน": 6, "กรกฎาคม": 7, "สิงหาคม": 8,
    "กันยายน": 9, "ตุลาคม": 10, "พฤศจิกายน": 11, "ธันวาคม": 12,
}


def format_date(d: date | str, fmt: str = "%Y-%m-%d") -> str:
    if isinstance(d, str):
        d = datetime.strptime(d, fmt).date()
    return d.strftime(fmt)


def parse_thai_date(text: str) -> date | None:
    """Parse a Thai-language date string like '15 สิงหาคม 2568'."""
    parts = text.strip().split()
    if len(parts) != 3:
        return None
    day, month_th, year_be = parts
    month = THAI_MONTHS.get(month_th)
    if not month:
        return None
    year_ce = int(year_be) - 543
    return date(year_ce, month, int(day))


def log_request(tool: str, params: dict) -> None:
    logger.info("Tool called: %s | params: %s", tool, params)
