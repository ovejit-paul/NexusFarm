"""
District-level outbreak tracking.

This is the idea that makes NexusFarm more than another image
classifier: one farmer's scan only helps that farmer, but many scans
grouped by district become an early warning nobody could get alone.

WHAT IS STORED
Only the diagnosis, the district, and the time. No photograph, no name,
no phone number, no GPS. A report cannot be traced back to a person,
which matters because farmers are reasonably cautious about data
concerning their land.

WHY SQLITE
It is a single file, needs no separate service, and handles far more
writes than this will ever see. Postgres would be the move if this grew
to many thousands of daily reports; it does not earn its operational
cost before then.
"""

import os
import sqlite3
from contextlib import closing
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from pydantic import BaseModel, Field, field_validator

from districts import normalize_district

DB_PATH = os.path.join(os.path.dirname(__file__), "outbreaks.db")

# A district needs at least this many reports of the same disease
# before anyone is warned. Two farmers finding late blight is ordinary;
# eight in three days is a pattern worth acting on.
MIN_REPORTS_FOR_ALERT = 3

# How far back an alert looks. Crop disease moves fast — a report from
# three weeks ago says nothing about this week's risk.
ALERT_WINDOW_DAYS = 7


class ScanReport(BaseModel):
    """What the app sends after a confident diagnosis."""

    district: str = Field(min_length=1, max_length=60)
    crop: str = Field(min_length=1, max_length=60)
    disease: str = Field(min_length=1, max_length=80)
    confidence: float = Field(ge=0.0, le=1.0)

    @field_validator("district")
    @classmethod
    def official_district(cls, value: str) -> str:
        # Rejected with 422 if it is not one of the 64. An unknown name
        # would otherwise open a fresh outbreak bucket nobody else reports
        # into — useless at best, a spam channel at worst.
        official = normalize_district(value)
        if official is None:
            raise ValueError("not a district of Bangladesh")
        return official


class Outbreak(BaseModel):
    """An aggregated warning for one district and disease."""

    district: str
    crop: str
    disease: str
    report_count: int
    days_span: int
    latest: str


def init_db() -> None:
    """Creates the table and indexes if they are not there yet."""
    with closing(sqlite3.connect(DB_PATH)) as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS reports (
                id         INTEGER PRIMARY KEY AUTOINCREMENT,
                district   TEXT    NOT NULL,
                crop       TEXT    NOT NULL,
                disease    TEXT    NOT NULL,
                confidence REAL    NOT NULL,
                created_at TEXT    NOT NULL
            )
            """
        )
        # Every alert query filters on district and date, so index both.
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_district_date "
            "ON reports (district, created_at)"
        )
        conn.commit()


def add_report(report: ScanReport) -> None:
    """Records one diagnosis. Called by the app, never by a person."""
    init_db()
    with closing(sqlite3.connect(DB_PATH)) as conn:
        conn.execute(
            "INSERT INTO reports (district, crop, disease, confidence, created_at) "
            "VALUES (?, ?, ?, ?, ?)",
            (
                # Already the official name — ScanReport validated it.
                report.district,
                report.crop.strip(),
                report.disease.strip(),
                report.confidence,
                datetime.now(timezone.utc).isoformat(),
            ),
        )
        conn.commit()


def get_outbreaks(
    district: str,
    window_days: int = ALERT_WINDOW_DAYS,
    min_reports: int = MIN_REPORTS_FOR_ALERT,
) -> List[Outbreak]:
    """Returns diseases reported often enough in one district to warn about.

    Sorted by report count, so the most widespread problem comes first.
    """
    init_db()
    cutoff = (datetime.now(timezone.utc) - timedelta(days=window_days)).isoformat()
    official = normalize_district(district)
    if official is None:
        # Not a district, so there can be no reports for it.
        return []
    district = official

    with closing(sqlite3.connect(DB_PATH)) as conn:
        rows = conn.execute(
            """
            SELECT crop,
                   disease,
                   COUNT(*)        AS report_count,
                   MIN(created_at) AS first_seen,
                   MAX(created_at) AS latest
            FROM reports
            WHERE district = ?
              AND created_at >= ?
              -- "Healthy" is a valid diagnosis but not an outbreak.
              AND LOWER(disease) != 'healthy'
            GROUP BY crop, disease
            HAVING COUNT(*) >= ?
            ORDER BY report_count DESC
            """,
            (district, cutoff, min_reports),
        ).fetchall()

    outbreaks = []
    for crop, disease, count, first_seen, latest in rows:
        try:
            span = (
                datetime.fromisoformat(latest) - datetime.fromisoformat(first_seen)
            ).days
        except Exception:
            span = 0

        outbreaks.append(
            Outbreak(
                district=district,
                crop=crop,
                disease=disease,
                report_count=count,
                days_span=max(span, 1),
                latest=latest,
            )
        )

    return outbreaks


def get_stats() -> dict:
    """Overall totals, useful for a demo and for checking the DB is alive."""
    init_db()
    with closing(sqlite3.connect(DB_PATH)) as conn:
        total = conn.execute("SELECT COUNT(*) FROM reports").fetchone()[0]
        districts = conn.execute(
            "SELECT COUNT(DISTINCT district) FROM reports"
        ).fetchone()[0]
        recent = conn.execute(
            "SELECT COUNT(*) FROM reports WHERE created_at >= ?",
            ((datetime.now(timezone.utc) - timedelta(days=7)).isoformat(),),
        ).fetchone()[0]

    return {
        "total_reports": total,
        "districts_covered": districts,
        "reports_last_7_days": recent,
    }
