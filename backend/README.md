# NexusFarm API

Serves the trained model for the web build. The phone app does not use
this — it runs the same model on-device.

## Run it locally

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Copy `model.tflite` and `labels.txt` from the app's `assets/model/`
into `backend/model/` first.

Check it works: open http://localhost:8000 — you should see
`{"status": "ok", ...}`.

## Point the web app at it

```bash
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

Without the flag it defaults to `http://localhost:8000` anyway, so for
local work you can leave it off.

## Deploy (free)

Render.com, as a Web Service:
- Build command: `pip install -r requirements.txt`
- Start command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
- Root directory: `backend`

Commit `model/model.tflite` and `model/labels.txt` so the deploy has
them. At 4.4 MB the model is small enough for git.

Then build the web app against the deployed URL:

```bash
flutter build web --dart-define=API_BASE=https://your-service.onrender.com
```

**Free tier sleeps after inactivity.** The first request after a idle
period takes 30-60 seconds to wake the container. Before a live demo,
open the API URL once to wake it.
