"""
Update prices by hand.

Use this when scrape_dam.py cannot reach the Department of
Agricultural Marketing — their site blocks automated requests at times
and is often slow. Reading today's figures off their page and typing
them here takes two minutes and always works.

    python update_prices_manually.py

Prices go in as a low-high range in taka per kg, which is how DAM
publishes them.
"""

from datetime import datetime, timezone

from prices import CropPrice, PriceSnapshot, save_snapshot

# ---------------------------------------------------------------
# EDIT THIS TABLE, then run the script.
# Look up today's figures at:
#   https://market.dam.gov.bd/market_daily_price_report?L=E
# ---------------------------------------------------------------
TODAY = {
    # crop name shown in the app : (low, high)
    "Rice (coarse)": (48, 50),
    "Rice (medium)": (55, 57),
    "Potato": (25, 30),
    "Tomato": (40, 50),
    "Onion (local)": (60, 64),
    "Green Chilli": (218, 237),
    "Lentil": (105, 115),
    "Garlic (local)": (173, 186),
}

MARKET = "Dhaka"


def main():
    prices = [
        CropPrice(crop=crop, low=float(low), high=float(high), market=MARKET)
        for crop, (low, high) in TODAY.items()
    ]

    snapshot = PriceSnapshot(
        collected_at=datetime.now(timezone.utc).isoformat(),
        source="Department of Agricultural Marketing (entered manually)",
        prices=prices,
    )
    save_snapshot(snapshot)

    print(f"Saved {len(prices)} prices, timestamped now.\n")
    for p in prices:
        change = (
            f"  ({p.change_percent:+.1f}%)" if p.change_percent is not None else ""
        )
        print(f"  {p.crop:20s} {p.low:6.2f} - {p.high:6.2f} Tk/kg{change}")


if __name__ == "__main__":
    main()
