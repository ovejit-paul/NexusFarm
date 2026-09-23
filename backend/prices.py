"""
Market price storage and endpoint.

The app never scrapes anything itself. It reads whatever is in the
cache file, which a separate job refreshes. That separation matters:
the Department of Agricultural Marketing site is slow and sometimes
unreachable, and a farmer opening the app should not have to wait on
it — or see an empty screen when it is down.

The cache always keeps the last good data, and the app shows when it
was collected so nobody mistakes stale prices for today's.
"""

import json
import os
from datetime import datetime, timezone
from typing import List, Optional

from pydantic import BaseModel

CACHE_PATH = os.path.join(os.path.dirname(__file__), "prices.json")


class CropPrice(BaseModel):
    crop: str
    unit: str = "kg"
    low: float
    high: float
    market: str
    # Percent change against the previous stored reading. None when we
    # have nothing to compare against yet.
    change_percent: Optional[float] = None


class PriceSnapshot(BaseModel):
    collected_at: str  # ISO8601 UTC
    source: str
    prices: List[CropPrice]


# Used only when the cache file does not exist yet, so a fresh checkout
# still shows something rather than an empty screen.
_SEED = PriceSnapshot(
    collected_at=datetime.now(timezone.utc).isoformat(),
    source="seed data — run scrape_dam.py to replace with live figures",
    prices=[
        CropPrice(crop="Rice (coarse)", low=48, high=50, market="Dhaka"),
        CropPrice(crop="Rice (medium)", low=55, high=57, market="Dhaka"),
        CropPrice(crop="Potato", low=25, high=30, market="Dhaka"),
        CropPrice(crop="Tomato", low=40, high=50, market="Dhaka"),
        CropPrice(crop="Onion (local)", low=60, high=64, market="Dhaka"),
        CropPrice(crop="Green Chilli", low=218, high=237, market="Dhaka"),
        CropPrice(crop="Lentil", low=105, high=115, market="Dhaka"),
        CropPrice(crop="Garlic (local)", low=173, high=186, market="Dhaka"),
    ],
)


def load_snapshot() -> PriceSnapshot:
    """Reads the cache, falling back to seed data if it is missing."""
    if not os.path.exists(CACHE_PATH):
        return _SEED

    try:
        with open(CACHE_PATH) as f:
            return PriceSnapshot(**json.load(f))
    except Exception:
        # A corrupted cache should not take the endpoint down.
        return _SEED


def save_snapshot(snapshot: PriceSnapshot) -> None:
    """Writes the cache, carrying over percent changes where possible."""
    previous = load_snapshot()
    previous_by_crop = {p.crop: p for p in previous.prices}

    for price in snapshot.prices:
        old = previous_by_crop.get(price.crop)
        if old and old.high > 0:
            new_mid = (price.low + price.high) / 2
            old_mid = (old.low + old.high) / 2
            if old_mid > 0:
                price.change_percent = round(
                    (new_mid - old_mid) / old_mid * 100, 1
                )

    with open(CACHE_PATH, "w") as f:
        json.dump(snapshot.model_dump(), f, indent=2)


def age_in_hours(snapshot: PriceSnapshot) -> float:
    """How old the data is, so the app can warn when it is stale."""
    try:
        collected = datetime.fromisoformat(snapshot.collected_at)
        if collected.tzinfo is None:
            collected = collected.replace(tzinfo=timezone.utc)
        delta = datetime.now(timezone.utc) - collected
        return round(delta.total_seconds() / 3600, 1)
    except Exception:
        return 0.0
