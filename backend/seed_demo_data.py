"""
Seeds realistic outbreak reports for a demo.

The outbreak banner is the project's core idea, but it stays hidden
until enough farmers have reported the same disease — which on a fresh
database is nobody. Run this before presenting so there is something to
show.

    python seed_demo_data.py

Uses your own district so the banner appears for the profile you demo
with. Change DISTRICT below to match.
"""

import random
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta, timezone

from outbreaks import DB_PATH, init_db

DISTRICT = "Dhaka"

# What to seed: (crop, disease, how many reports, spread over N days)
PATTERN = [
    ("Potato", "Late Blight", 12, 3),
    ("Tomato", "Early Blight", 5, 4),
    ("Potato", "Early Blight", 3, 2),
]


def main():
    init_db()
    now = datetime.now(timezone.utc)
    rows = []

    for crop, disease, count, days in PATTERN:
        for _ in range(count):
            # Spread the reports across the window so the "last N days"
            # span in the banner looks natural rather than all at once.
            when = now - timedelta(
                days=random.uniform(0, days),
                hours=random.uniform(0, 12),
            )
            rows.append(
                (
                    DISTRICT,
                    crop,
                    disease,
                    round(random.uniform(0.82, 0.97), 4),
                    when.isoformat(),
                )
            )

    with closing(sqlite3.connect(DB_PATH)) as conn:
        conn.executemany(
            "INSERT INTO reports (district, crop, disease, confidence, created_at) "
            "VALUES (?, ?, ?, ?, ?)",
            rows,
        )
        conn.commit()

    print(f"Seeded {len(rows)} reports for {DISTRICT}:")
    for crop, disease, count, days in PATTERN:
        print(f"  {count:2d}x {disease} in {crop} over {days} days")
    print("\nThe banner will now show the largest of these.")
    print("Set your profile district to", DISTRICT, "before demoing.")


if __name__ == "__main__":
    main()
