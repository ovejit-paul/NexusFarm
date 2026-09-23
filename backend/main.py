"""
NexusFarm inference API.

Serves the same trained model the phone app runs on-device. The web
build calls this because a browser cannot load the native TensorFlow
Lite library.

RUN LOCALLY
    pip install -r requirements.txt
    uvicorn main:app --reload --port 8000

Then open http://localhost:8000/docs to try it in a browser.

MODEL FILES
Put these next to this file, in a folder called model/:
    model/model.tflite
    model/labels.txt
Use the same pair the phone app uses — a labels.txt from a different
training run gives confident but completely wrong disease names,
because the line order is the model's class order.
"""

import base64
import io
import os

import numpy as np
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from PIL import Image
from pydantic import BaseModel

from outbreaks import (
    Outbreak,
    ScanReport,
    add_report,
    get_outbreaks,
    get_stats,
)
from prices import age_in_hours, load_snapshot
from districts import normalize_district
from security import (
    MAX_IMAGE_PIXELS,
    check_image_size,
    check_prediction_limit,
    check_report_limit,
)
from text_triage import TextQuery, TextTriageResult, triage

# The Interpreter has moved twice across TensorFlow versions, so try
# each known location. tflite_runtime is the smallest and is what a
# deployed container should install; the others are fallbacks for a
# machine that already has full TensorFlow.
Interpreter = None
for _path in (
    "tflite_runtime.interpreter",
    "ai_edge_litert.interpreter",
    "tensorflow.lite.python.interpreter",
):
    try:
        import importlib

        Interpreter = importlib.import_module(_path).Interpreter
        break
    except (ImportError, AttributeError):
        continue

if Interpreter is None:
    raise ImportError(
        "No TFLite interpreter found. Install one of: tflite-runtime, "
        "ai-edge-litert, or tensorflow."
    )

MODEL_PATH = os.path.join(os.path.dirname(__file__), "model", "model.tflite")
LABELS_PATH = os.path.join(os.path.dirname(__file__), "model", "labels.txt")
INPUT_SIZE = 224

app = FastAPI(title="NexusFarm API", version="1.0")

# The Flutter web build is served from a different origin, so the
# browser will not call this at all without CORS headers.
# Browsers block cross-origin calls unless the server allows them. In
# production set ALLOWED_ORIGINS to the deployed web app's URL; "*" is
# only a convenience for local development.
_origins = os.environ.get("ALLOWED_ORIGINS", "*")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"] if _origins == "*" else
                  [o.strip() for o in _origins.split(",") if o.strip()],
    allow_methods=["POST", "GET"],
    allow_headers=["Content-Type"],
)

# Pillow refuses images above this, which blocks decompression bombs —
# a small file that expands into a bitmap large enough to exhaust memory.
Image.MAX_IMAGE_PIXELS = MAX_IMAGE_PIXELS


@app.exception_handler(Exception)
async def unhandled_error(request: Request, exc: Exception):
    """Returns a generic message instead of a stack trace.

    A penetration test of the unprotected version produced a 500 with a
    full traceback, which tells an attacker the framework, file paths and
    library versions. Nothing about the internals should reach a client.
    """
    return JSONResponse(
        status_code=500,
        content={"detail": "Something went wrong handling that request."},
    )

_interpreter = None
_labels = None


def _load():
    """Loads the model once, on first request rather than at import.

    Free hosting tiers kill a process that takes too long to start, so
    deferring the load keeps the container booting quickly.
    """
    global _interpreter, _labels

    if _interpreter is not None:
        return

    if not os.path.exists(MODEL_PATH):
        raise HTTPException(
            status_code=503,
            detail="Model file not found. Put model.tflite in the model/ folder.",
        )

    _interpreter = Interpreter(model_path=MODEL_PATH)
    _interpreter.allocate_tensors()

    with open(LABELS_PATH) as f:
        _labels = [line.strip() for line in f if line.strip()]


class PredictRequest(BaseModel):
    image: str  # base64-encoded image bytes


class PredictResponse(BaseModel):
    label: str
    confidence: float


@app.get("/")
def health():
    """Simple liveness check, also used to wake a sleeping free-tier host."""
    return {"status": "ok", "model_loaded": _interpreter is not None}


@app.post("/predict", response_model=PredictResponse)
def predict(body: PredictRequest, request: Request):
    check_prediction_limit(request)
    check_image_size(body.image)

    _load()

    try:
        image_bytes = base64.b64decode(body.image)
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception:
        raise HTTPException(status_code=400, detail="Could not read that image.")

    image = image.resize((INPUT_SIZE, INPUT_SIZE))

    # Values stay in 0-255, NOT divided by 255 — EfficientNet's
    # preprocess_input is inside the exported model graph, so the model
    # normalises its own input. Scaling here too would scale twice and
    # produce confident nonsense. This must match the Dart code exactly.
    array = np.asarray(image, dtype=np.float32)
    array = np.expand_dims(array, axis=0)

    input_details = _interpreter.get_input_details()
    output_details = _interpreter.get_output_details()

    _interpreter.set_tensor(input_details[0]["index"], array)
    _interpreter.invoke()

    scores = _interpreter.get_tensor(output_details[0]["index"])[0]
    best = int(np.argmax(scores))

    return PredictResponse(
        label=_labels[best],
        confidence=float(scores[best]),
    )


class PricesResponse(BaseModel):
    collected_at: str
    source: str
    age_hours: float
    prices: list


@app.get("/prices", response_model=PricesResponse)
def prices():
    """Daily crop prices from the cache.

    Never scrapes on request — `scrape_dam.py` refreshes the cache on a
    schedule. That keeps this endpoint fast and keeps a slow upstream
    site from becoming the app's problem.

    `age_hours` lets the app say how old the figures are instead of
    presenting stale prices as today's.
    """
    snapshot = load_snapshot()
    return PricesResponse(
        collected_at=snapshot.collected_at,
        source=snapshot.source,
        age_hours=age_in_hours(snapshot),
        prices=[p.model_dump() for p in snapshot.prices],
    )


# ---------------------------------------------------------------
# Outbreak tracking
# ---------------------------------------------------------------


class OutbreaksResponse(BaseModel):
    district: str
    outbreaks: list
    window_days: int


@app.post("/reports", status_code=201)
def submit_report(report: ScanReport, request: Request):
    """Records one diagnosis so it can count towards a district warning.

    The app calls this only for confident diagnoses — a follow-up
    request is not a finding, and counting it would inflate the numbers.
    Nothing identifying is stored: no photo, no name, no location beyond
    the district the farmer typed into their profile.
    """
    # Without this, a single source can fabricate a district-wide alert.
    check_report_limit(request, report.district)

    add_report(report)
    return {"recorded": True}


@app.get("/outbreaks", response_model=OutbreaksResponse)
def outbreaks(
    district: str = Query(min_length=1, max_length=60),
    # Unbounded, this raised OverflowError and returned a 500 with a
    # stack trace. Disease risk is a question about recent weeks anyway.
    window_days: int = Query(default=7, ge=1, le=90),
):
    """Diseases reported often enough in one district to be worth a warning.

    Returns an empty list when nothing crosses the threshold, which is
    the normal case and is not an error — the app simply shows no banner.
    """
    found = get_outbreaks(district, window_days=window_days)
    return OutbreaksResponse(
        district=normalize_district(district) or district.strip(),
        outbreaks=[o.model_dump() for o in found],
        window_days=window_days,
    )


@app.get("/stats")
def stats():
    """Totals across all districts. Handy during a demo."""
    return get_stats()


# ---------------------------------------------------------------
# Text triage
# ---------------------------------------------------------------


@app.post("/triage", response_model=TextTriageResult)
def triage_text(query: TextQuery):
    """Matches a farmer's written description to a known disease.

    Returns a label from our own list, or null when it cannot tell.
    Treatment text is never generated here — the app looks it up from
    its verified content using the returned label, exactly as it does
    for a photo diagnosis.
    """
    return triage(query.description)
