# NexusFarm — current state

## Working, end to end

| Feature | Notes |
|---|---|
| Disease detection | Real trained model, on-device on mobile |
| 70% confidence rule | Withholds diagnosis, asks for another photo |
| Treatment + pre-harvest interval | From reviewed content, never generated |
| **Outbreak alerts** | **Real now** — SQLite, counts by district |
| **Text diagnosis** | **Real now** — LLM triage, verified treatment |
| **Saved profile & history** | **Persists** across app restarts |
| Fertilizer calculator | 13 crops, split schedules |
| Market prices | Live endpoint, cache, staleness shown |
| Crop library | Offline reference |
| Web build | Same codebase, API-backed inference |

## What changed in this pass

**Outbreak alerts are no longer fake.** They were a hardcoded
"12 farmers" string. Now every confident diagnosis posts an anonymous
report (district, crop, disease, time — no photo, no name), and the
banner shows real counts above a threshold of 3 reports in 7 days.
Healthy scans are excluded. District names are normalised so "savar",
are matched against the official list of 64 districts, so old spellings
such as "Bogra" group with "Bogura" and invented names are refused.

**Text diagnosis does something.** It previously always said "send a
photo". Now the description goes to a language model — but the model is
only allowed to pick from our fixed disease list, never to name a
chemical or a dose. Treatment comes from our own reviewed data, same as
a photo diagnosis. If the model picks a label outside the list, it is
rejected.

That constraint is the point. A model asked for pesticide advice will
invent it, which would contradict everything else this project does.

**Profile and history survive a restart.** They were memory-only.

## Setup for the new parts

**Text triage** needs a free Gemini key:

```bash
export GEMINI_API_KEY=your_key    # from aistudio.google.com/apikey
```

Without it the endpoint still answers — it just asks for a photo, as
before. Nothing breaks.

**Before a demo**, seed the outbreak data so the banner has something
to show:

```bash
cd backend
python seed_demo_data.py
```

Then set your profile district to **Dhaka** in the app.

## Still not done

- Field-condition accuracy is unmeasured (92% is a lab figure)
- Treatment content is not reviewed by an agronomist
- Rice and wheat are in the library but not in the model
- No login — reports are anonymous by design, but there is also no way
  to correct a bad one
