"""
Abuse protection for the public API.

THREAT MODEL
The outbreak feature is the one worth attacking. Every alert is built
from unauthenticated reports, so anyone who can reach the endpoint can
either fabricate a district-wide panic or bury a real outbreak under
noise. A penetration test of the unprotected version injected 200 fake
reports in half a second and the banner dutifully announced them.

We cannot require accounts — the app deliberately has no login, and
adding one to stop spam would cost more than it gains. So the defence
is layered instead:

  1. Per-IP rate limits, so one source cannot flood
  2. A cap on how many reports one IP contributes to one district
  3. Payload size limits before anything is decoded
  4. Bounded query parameters

None of this stops a determined attacker with many IPs. It stops the
realistic ones: a bored visitor, a broken client retrying in a loop, and
a single machine trying to skew a district. Genuine defence against a
distributed attack needs identity, which is future work.
"""

import time
from collections import defaultdict, deque
from threading import Lock

from fastapi import HTTPException, Request

# ---------------------------------------------------------------
# Limits
# ---------------------------------------------------------------

# A real farmer scans a handful of leaves in a session. Twenty reports
# an hour from one address is already generous.
REPORTS_PER_HOUR = 20
REPORTS_PER_DAY = 60

# One address should not be able to single-handedly trigger a district
# alert. The alert threshold is 3 reports, so capping one IP below that
# means at least two sources are needed for any warning to appear.
MAX_PER_IP_PER_DISTRICT_PER_DAY = 2

# Inference is the expensive endpoint.
PREDICTIONS_PER_HOUR = 60

# Base64 inflates by about a third, so this allows roughly a 3 MB photo.
# The app already compresses to 85% quality at phone resolution, which
# lands far below this.
MAX_IMAGE_B64_CHARS = 4_000_000

# Guards against decompression bombs: a small file that expands into a
# huge bitmap. 50 megapixels is far beyond any phone camera.
MAX_IMAGE_PIXELS = 50_000_000


class _SlidingWindow:
    """Counts events per key within a time window.

    In-memory on purpose. A single container serves this app, and the
    counters are cheap to rebuild on restart — losing them briefly is
    less harmful than the operational cost of Redis for a project at
    this stage.
    """

    def __init__(self):
        self._events: dict[str, deque] = defaultdict(deque)
        self._lock = Lock()
        self._last_sweep = time.time()

    def hit(self, key: str, limit: int, window_seconds: int) -> bool:
        """Records an event. Returns False if the limit is already reached."""
        now = time.time()

        with self._lock:
            self._maybe_sweep(now)

            events = self._events[key]
            cutoff = now - window_seconds
            while events and events[0] < cutoff:
                events.popleft()

            if len(events) >= limit:
                return False

            events.append(now)
            return True

    def count(self, key: str, window_seconds: int) -> int:
        now = time.time()
        with self._lock:
            events = self._events[key]
            cutoff = now - window_seconds
            while events and events[0] < cutoff:
                events.popleft()
            return len(events)

    def _maybe_sweep(self, now: float) -> None:
        """Drops empty keys occasionally so memory does not creep up."""
        if now - self._last_sweep < 600:
            return
        self._last_sweep = now
        empty = [k for k, v in self._events.items() if not v]
        for k in empty:
            del self._events[k]


_reports = _SlidingWindow()
_predictions = _SlidingWindow()
_per_district = _SlidingWindow()


def client_ip(request: Request) -> str:
    """Best-effort client address.

    Behind a proxy the socket address is the proxy, so X-Forwarded-For is
    used when present. That header is client-controlled and therefore
    spoofable — it is good enough to separate ordinary users, not to
    stop someone who is deliberately rotating it.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def check_report_limit(request: Request, district: str) -> None:
    """Rate limits outbreak reporting. Raises 429 when exceeded."""
    ip = client_ip(request)

    if not _reports.hit(f"h:{ip}", REPORTS_PER_HOUR, 3600):
        raise HTTPException(
            status_code=429,
            detail="Too many reports from this device. Try again later.",
        )

    if not _reports.hit(f"d:{ip}", REPORTS_PER_DAY, 86400):
        raise HTTPException(
            status_code=429,
            detail="Daily reporting limit reached for this device.",
        )

    # The important one: stop a single source from manufacturing an alert.
    district_key = f"{ip}|{district.strip().lower()}"
    if not _per_district.hit(
        district_key, MAX_PER_IP_PER_DISTRICT_PER_DAY, 86400
    ):
        raise HTTPException(
            status_code=429,
            detail=(
                "This device has already contributed the maximum number of "
                "reports for this district today."
            ),
        )


def check_prediction_limit(request: Request) -> None:
    ip = client_ip(request)
    if not _predictions.hit(f"p:{ip}", PREDICTIONS_PER_HOUR, 3600):
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please wait a few minutes.",
        )


def check_image_size(b64: str) -> None:
    """Rejects oversized payloads before decoding anything."""
    if len(b64) > MAX_IMAGE_B64_CHARS:
        raise HTTPException(
            status_code=413,
            detail="Image too large. Please send a smaller photo.",
        )
