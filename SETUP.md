# NexusFarm — mobile + web

Same codebase, both platforms. The only difference is where the model runs.

| | Mobile | Web |
|---|---|---|
| Inference | TensorFlow Lite, on-device | Calls our API |
| Internet | Not needed | Needed |
| Photo leaves device | No | Yes (to our own API) |

A browser cannot load the native TFLite library, which is why the web
build needs the API. The phone build is unchanged and still fully offline.

---

## 1. Put the model in place

Copy from your existing project:

```
assets/model/model.tflite     -> app, for mobile
assets/model/labels.txt

backend/model/model.tflite    -> API, for web
backend/model/labels.txt
```

Both copies must come from the same training run.

## 2. Run on mobile (unchanged)

```bash
flutter pub get
flutter run
```

## 3. Run the backend

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Check http://localhost:8000 shows `{"status":"ok"}`.

## 4. Run on web

```bash
flutter run -d chrome --dart-define=API_BASE=http://localhost:8000
```

## 5. Deploy

**Backend** — Render.com, new Web Service:
- Root directory: `backend`
- Build: `pip install -r requirements.txt`
- Start: `uvicorn main:app --host 0.0.0.0 --port $PORT`

**Web app** — Firebase Hosting:
```bash
flutter build web --dart-define=API_BASE=https://your-service.onrender.com
firebase init hosting     # public directory: build/web
firebase deploy
```

---

## Before a live demo

Free hosting sleeps when idle. **Open the API URL once a minute before
you present** — the first request after sleeping takes 30-60 seconds.

If the API is unreachable the app does not show an error; it falls back
to sample results. That keeps a demo alive on a flaky connection, but it
also means you should check the `i` dialog to confirm which mode is
actually running.

---

## What changed from the phone-only version

- `tflite_service.dart` became `inference_mobile.dart`, behind the
  `InferenceBackend` interface in `inference_backend.dart`
- `inference_web.dart` added — same interface, HTTP instead of TFLite
- Photos now travel as `Uint8List` rather than `File`, because `File`
  does not exist in a browser
- `Image.file` became `Image.memory` for the same reason
- Fertilizer calculator added as a fifth tab

---

## Verified before shipping

The model was loaded and run end to end in this environment:

- Model input `[1, 224, 224, 3]` float32, output `[1, 6]` float32
- Output size matches the 6 lines in `labels.txt`
- Softmax sums to 1.0000
- `POST /predict` returns `{"label": ..., "confidence": ...}` — exactly
  what `inference_web.dart` parses
- A bad image returns 400 with a readable message, not a crash
- `model_loaded` is false until the first request, then true, confirming
  the lazy load works

One useful detail from that test: a synthetic image that was not a real
leaf scored 0.57, which is below the 0.70 threshold — so the app would
have asked for another photo instead of naming a disease. The safety
behaviour works on real model output, not just in theory.

## Note on the interpreter import

`tf.lite.Interpreter` moved location between TensorFlow versions and is
deprecated in 2.20+. `main.py` tries three import paths in order
(`tflite_runtime`, `ai_edge_litert`, `tensorflow.lite.python`) and uses
whichever is present, so it runs on an old or new install without edits.
