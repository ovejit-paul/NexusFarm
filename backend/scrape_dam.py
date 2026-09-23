"""
Fetches daily prices from the Department of Agricultural Marketing and
writes them into the cache the API serves.

    python scrape_dam.py

Run it on a schedule (cron, or a Render cron job) — not from the app.
DAM's site is slow and sometimes unreachable, so nothing user-facing
should ever wait on it.

If the fetch fails, the existing cache is left untouched. Yesterday's
prices are far more useful to a farmer than an empty screen.

NOTE ON FRAGILITY
DAM publishes no API, so this parses HTML. If they change their page
layout this will stop matching and log a warning — it will not crash,
and it will not overwrite good data with nothing. Check the output
occasionally and adjust CROP_PATTERNS if the names change.
"""

import re
import sys
from datetime import datetime, timezone

import requests

from prices import CropPrice, PriceSnapshot, save_snapshot

URL = "https://market.dam.gov.bd/market_daily_price_report?L=E"
TIMEOUT = 30

# DAM's commodity names mapped to what the app shows. Left side is
# matched case-insensitively against their page.
CROP_PATTERNS = {
    "Aman-Coarse": "Rice (coarse)",
    "Aman-Medium": "Rice (medium)",
    "Aman-Fine": "Rice (fine)",
    "Potato": "Potato",
    "Tomato": "Tomato",
    "Onion-local": "Onion (local)",
    "Green Chili": "Green Chilli",
    "Garlic-local": "Garlic (local)",
    "Ginger-local": "Ginger (local)",
    "Mung": "Mung Bean",
    "Gram-Whole": "Gram",
    "Soybean": "Soybean Oil",
}


def fetch_page() -> str:
    response = requests.get(
        URL,
        timeout=TIMEOUT,
        headers={"User-Agent": "NexusFarm/1.0 (student project)"},
    )
    response.raise_for_status()
    return response.text


def parse_prices(html: str) -> list[CropPrice]:
    """Pulls 'Name: 60.00 - 64.00' pairs out of the page text.

    The ticker on DAM's page renders as plain text in that shape, which
    is more stable to match than their table markup.
    """
    prices = []

    for dam_name, app_name in CROP_PATTERNS.items():
        # e.g. "Onion-local: 60.00 - 64.00"
        pattern = re.escape(dam_name) + r"\s*:\s*([\d.]+)\s*-\s*([\d.]+)"
        match = re.search(pattern, html, re.IGNORECASE)
        if not match:
            continue

        try:
            low = float(match.group(1))
            high = float(match.group(2))
        except ValueError:
            continue

        if low <= 0 or high <= 0:
            continue

        prices.append(
            CropPrice(crop=app_name, low=low, high=high, market="Dhaka")
        )

    return prices


def main() -> int:
    print(f"Fetching {URL}")

    try:
        html = fetch_page()
    except Exception as exc:
        print(f"  FAILED: {exc}")
        print("  Cache left unchanged — the app keeps serving the last good data.")
        return 1

    prices = parse_prices(html)

    if not prices:
        print("  Page fetched but no prices matched.")
        print("  DAM may have changed their layout; check CROP_PATTERNS.")
        print("  Cache left unchanged.")
        return 1

    snapshot = PriceSnapshot(
        collected_at=datetime.now(timezone.utc).isoformat(),
        source="Department of Agricultural Marketing (market.dam.gov.bd)",
        prices=prices,
    )
    save_snapshot(snapshot)

    print(f"  Saved {len(prices)} prices:")
    for p in prices:
        print(f"    {p.crop:20s} {p.low:7.2f} - {p.high:7.2f} Tk/kg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
