# Contest checklist — WSDG 2026

Work top to bottom. Each section assumes the one above is done.

---

## A. Before you travel

### Repository
- [ ] Take four screenshots from the running app (see below)
- [ ] Put them in `docs/images/` with these exact names:
      `screen_diagnosis.png` · `screen_followup.png` ·
      `screen_fertilizer.png` · `screen_outbreak.png`
- [ ] Open `README.md`, delete the `<!--` and `-->` around the
      Screenshots block
- [ ] Push (see `PUSH_TO_GITHUB.md`)
- [ ] **Scan the QR on your printed poster with your own phone.** Confirm
      it opens the repo and the README shows images. This is what a judge
      does first.

### The four screenshots — how to get each
| File | How to produce it |
|---|---|
| `screen_diagnosis` | Pick a clear diseased potato leaf → full result card |
| `screen_followup` | Photo of something that is not a leaf → "Need one more photo" |
| `screen_fertilizer` | Potato, 2 bigha, medium, loam → result page |
| `screen_outbreak` | Run `seed_demo_data.py`, district = Dhaka → banner visible |

### Build a standalone APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`. Install it on
your phone. **Demo from the installed app, not from `flutter run`** — no
laptop cable, no debug banner, no chance of a hot-reload hiccup.

### Keys and data
- [ ] Gemini key set (`GEMINI_API_KEY`) — or accept text diagnosis will
      ask for a photo instead
- [ ] `python update_prices_manually.py` with that morning's figures
- [ ] `python seed_demo_data.py` so the outbreak banner has something
- [ ] Profile district set to **Dhaka** in the app
- [ ] `python pentest.py` → **5/5 passed**

### Backups — assume the venue wifi will fail
- [ ] **Screen-record the full demo** (3-4 minutes) on the phone. If
      anything fails live, play this.
- [ ] Gallery holds 4-5 diseased leaf photos plus one non-leaf photo
- [ ] Poster PDF on the phone, in case a judge asks for a copy
- [ ] Phone charged, charger packed

---

## B. At the venue

### Ten minutes before judging
- [ ] **Airplane mode ON.** The diagnosis must work offline — that is
      the claim. Test one photo to be sure.
- [ ] Clear old scan history if it looks cluttered
      (Profile → it shows newest first)
- [ ] Open the app to Crop Doctor, ready

### If the backend is on free hosting
Free tiers sleep when idle and take 30-60 s to wake. **Open the API URL
in a browser one minute before you present.** Otherwise outbreaks and
prices show fallback data on the first tap.

---

## C. The demo — 3 to 4 minutes

Order matters: each step builds the argument for the next.

| # | Show | Say (one line) |
|---|---|---|
| 1 | Airplane mode icon | "No internet. Everything you see runs on the phone." |
| 2 | Diseased leaf → diagnosis | "94% — and the confidence is shown, not hidden." |
| 3 | Point at the red box | "Pre-harvest interval: when it is safe to harvest after spraying." |
| 4 | Non-leaf photo → follow-up | **"Below 70%, it refuses to guess."** ← the key moment |
| 5 | Outbreak banner | "Many farmers' scans become one district warning." |
| 6 | Fertilizer screen | "Answers in urea and TSP, not nitrogen." |

**Step 4 is the most important moment of the entire presentation.** Pause
after it. Let the judge react before moving on.

---

## D. Questions you will be asked

**"Is 92% good?"**
> "It is a laboratory figure. PlantVillage photos are single leaves on
> plain backgrounds. Field accuracy will be lower — measuring that gap on
> real field photos is our most important next step."

*Say this before they ask if you can. Volunteered, it reads as rigour.
Extracted, it reads as concealment.*

**"Why 70%?"**
> "Set by judgement, not yet by data. Once we have field images we will
> tune it against how often wrong answers appear above each cutoff."

**"Did farmers use it?"**
> Answer honestly with whatever is true by then. If field testing is
> done, give the numbers. If not, say so and describe the plan.

**"Why not just use ChatGPT?"**
> "A language model will invent a pesticide name. Ours is only allowed to
> choose from diseases we have verified content for — the treatment text
> never comes from the model."

**"What about security?"**
> "I ran a penetration test and found outbreak data poisoning — one
> client could fake 200 reports in half a second. Now one source is
> capped below the alert threshold, so no single device can create a
> warning." *Offer to run `pentest.py` live.*

**"Did you build this alone?"**
> Yes. State it plainly.

**"What next?"**
> "Field validation first, then extending to livestock on my own mixed
> farm — the same safety idea as the pre-harvest interval applies to
> milk and meat after veterinary treatment."

---

## E. If something breaks

| Problem | Do this |
|---|---|
| App crashes | Play the screen recording. Say so calmly. |
| Wrong diagnosis on a real leaf | "That is exactly the lab-to-field gap I mentioned." It proves your honesty. |
| Outbreak banner missing | District in Profile not set to Dhaka, or seed not run |
| Prices say "offline" | API asleep or no wifi — the fallback is by design; explain it |
| Judge asks for code | Scan the QR together |

A failure handled calmly scores better than a flawless demo nobody
questions. Judges remember how you respond.
