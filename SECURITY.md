# Security review

A penetration test was run against the API before deployment. Three
exploitable issues were found and fixed. This document records what was
found, what was done, and what remains open — the last part matters as
much as the first.

## Findings

### 1. Outbreak data poisoning — critical, fixed

**Before.** `/reports` had no authentication and no rate limiting. A
single client injected **200 fabricated reports in 0.5 seconds**, and the
app's outbreak banner announced them as real:

```
-> BANNER NOW SHOWS: 200 farmers reported 'FAKE PANIC DISEASE'
```

This attacked the project's central feature. An attacker could invent a
district-wide panic, or bury a genuine outbreak under manufactured noise
so nobody trusted the alerts.

**Fix.** Layered limits in `security.py`:

- 20 reports per IP per hour, 60 per day
- **A hard cap of 2 reports per IP per district per day.** The alert
  threshold is 3, so no single source can produce a warning on its own —
  at least two independent reporters are required.

**After.** Of 200 attempts, 2 were accepted and 198 rejected with 429.
No outbreak was created.

**Why not simply require accounts.** The app deliberately has no login.
Adding one to stop spam would cost every farmer a signup and gain little
against an attacker willing to create accounts. Rate limiting keeps the
barrier where it belongs.

### 2. Unbounded request payload — moderate, fixed

**Before.** `/predict` accepted and decoded a 27 MB base64 payload. A
handful of concurrent requests would exhaust memory on a free-tier
container.

**Fix.** Payload length is checked *before* decoding, capped at
4,000,000 base64 characters — roughly a 3 MB photo, far above what the
app actually sends. `Image.MAX_IMAGE_PIXELS` is also set, which blocks
decompression bombs: small files that expand into enormous bitmaps.

**After.** The same payload returns 413 without being decoded.

### 3. Unhandled exception leaking internals — moderate, fixed

**Before.** `GET /outbreaks?window_days=999999` raised `OverflowError`
inside a date calculation and returned a 500 carrying a full Python
traceback — framework, file paths and library versions all disclosed.

**Fix.** `window_days` is bounded to 1-90 and `district` to 60
characters, both rejected at validation with 422. A catch-all handler
returns a generic message so no traceback can ever reach a client.

**After.** 422, no crash, nothing disclosed.

### 4. Permissive CORS — low, fixed

`allow_origins=["*"]` let any website call the API from a browser. Now
read from the `ALLOWED_ORIGINS` environment variable; set it to the
deployed web app's URL in production.

## Verified safe

**SQL injection.** Every query in `outbreaks.py` uses parameter binding.
No string interpolation or concatenation appears in any statement.

**API key exposure.** The Gemini key lives in a server environment
variable and is never sent to a client. Putting it in the app would make
it extractable from the APK.

**Prompt injection into treatment advice.** The language model is given
a fixed list of diseases and permitted only to choose from it. Any label
outside that list is rejected. Treatment text comes from reviewed
content, never from the model — so a crafted description cannot make the
app recommend a chemical.

**Photograph privacy.** On mobile, inference is on-device and no image
is transmitted. On web the image reaches our own API and is not stored.

## Still open

**Distributed attacks.** Rate limits are per IP. An attacker with many
addresses could still skew a district. Real defence needs identity —
device attestation or phone verification — which is future work.

**`X-Forwarded-For` is spoofable.** Behind a proxy the client address is
taken from that header, which a client controls. It separates ordinary
users; it does not stop someone deliberately rotating it.

**Counters are in memory.** They reset when the container restarts,
briefly clearing limits. Acceptable at this scale; Redis would be the
answer if traffic justified it.

**No transport security enforced in code.** HTTPS is assumed to be
terminated by the host. On Render and Firebase Hosting it is, but the
application does not itself refuse plain HTTP.

## Reproducing the test

The attack script used is in `backend/pentest.py`:

```bash
cd backend
python pentest.py
```

It runs all four attacks and reports whether each is blocked.
