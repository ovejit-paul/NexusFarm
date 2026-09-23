# Live market prices — how it works

## The design, and why

```
DAM website  →  scraper (or manual entry)  →  prices.json cache  →  /prices  →  app
                     runs on a schedule          always readable      fast
```

The app never touches DAM directly. Three reasons:

**Their site is slow and sometimes blocks automated requests.** When
tested from here it timed out once and returned 403 another time. A
farmer opening the Market tab should not wait on that, and a live demo
should not depend on it.

**Yesterday's prices beat an empty screen.** If a refresh fails the
cache is left untouched, so the app keeps serving the last good data.

**Honesty about staleness.** The API returns `age_hours` and the screen
says "Updated 3 hours ago" or "Updated 2 days ago". Above 36 hours the
banner turns amber. A stale price shown as today's is worse than no
price.

---

## Refreshing the prices

### Option A — the scraper

```bash
cd backend
python scrape_dam.py
```

**This is unverified against the live site.** DAM returned 403 from
this environment, which may be their bot protection or may be a network
restriction here. Try it on your own machine. If it prints prices, put
it on a schedule. If it fails, use Option B — it will not break
anything either way, because a failed run leaves the cache alone.

### Option B — by hand (always works)

Open `backend/update_prices_manually.py`, edit the `TODAY` table with
figures from https://market.dam.gov.bd/market_daily_price_report?L=E,
then:

```bash
python update_prices_manually.py
```

Two minutes, and it never fails. For the competition this is the
reliable choice — run it the morning of the demo.

### Scheduling Option A

Cron, daily at 7am:

```
0 7 * * * cd /path/to/backend && python scrape_dam.py >> scrape.log 2>&1
```

On Render, add a Cron Job service with the same command.

---

## What the app shows

Percent change is calculated against the previous stored reading, so it
only appears from the second update onward. That is deliberate — showing
"0%" for a first reading would imply a comparison that was never made.

If the server is unreachable the app falls back to built-in sample
figures and says so plainly: "Could not reach the server. Showing
typical prices, not today's."

---

## Before the demo

1. Run `update_prices_manually.py` with the morning's real figures
2. Open the API `/prices` URL once to confirm it responds
3. Check the Market tab shows "Updated just now"

If you are on free hosting, step 2 also wakes the sleeping container.
