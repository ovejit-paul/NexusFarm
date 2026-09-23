"""
Text triage: turning a farmer's description into a candidate disease.

WHY THIS IS DELIBERATELY LIMITED
A language model asked "what pesticide should I use" will answer, and
it may invent a chemical name or a dose. That is unacceptable here —
the whole project rests on not giving confident wrong advice.

So the model is never asked for treatment. It is given the fixed list
of diseases the app already has verified content for, and asked only to
pick which one the description matches, or to say it cannot tell. The
treatment text then comes from our own reviewed data, exactly as it
does for a photo diagnosis.

The model narrows down. It does not prescribe.

SETUP
Get a free key from https://aistudio.google.com/apikey and set it:

    export GEMINI_API_KEY=your_key_here

Without a key the endpoint still answers — it just falls back to asking
for a photo, which is what the app did before.
"""

import json
import os
from typing import Optional

import requests
from pydantic import BaseModel, Field

API_KEY = os.environ.get("GEMINI_API_KEY", "")
MODEL = "gemini-2.0-flash"
ENDPOINT = (
    f"https://generativelanguage.googleapis.com/v1beta/models/{MODEL}:generateContent"
)
TIMEOUT = 15

# The only answers the language model is allowed to give: exactly the
# classes the image model was trained on, read from the same labels.txt.
# Hard-coding them meant a retrained model with rice in it could never be
# matched from a written description, because the list still said
# potato and tomato.
_LABELS_PATH = os.path.join(os.path.dirname(__file__), "model", "labels.txt")
_FALLBACK = [
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___healthy",
]


def _load_known_diseases():
    try:
        with open(_LABELS_PATH) as f:
            labels = [line.strip() for line in f if line.strip()]
        return labels or _FALLBACK
    except OSError:
        return _FALLBACK


KNOWN_DISEASES = _load_known_diseases()

SYSTEM_PROMPT = """You help triage crop disease descriptions from farmers in Bangladesh.

You will be given a farmer's description of what they see on their plants.

Your ONLY job is to decide which of these labels best matches, or to say you cannot tell:
{labels}

Rules:
- Reply with JSON only. No prose, no markdown, no code fences.
- Format: {{"label": "<one label or null>", "reason": "<one short sentence>", "confident": <true or false>}}
- Set "label" to null and "confident" to false if the description is vague, mentions a crop not in the list, or could match several diseases.
- NEVER name a pesticide, chemical, or dose. You are not asked for treatment.
- Judge only from described symptoms. Do not guess to be helpful.
- "reason" must be understandable to a farmer with no technical training.
"""


class TextQuery(BaseModel):
    description: str = Field(min_length=1, max_length=1000)


class TextTriageResult(BaseModel):
    # A label from KNOWN_DISEASES, or None when the model could not tell.
    label: Optional[str] = None
    reason: str = ""
    confident: bool = False
    # False when no API key is set or the call failed, so the app knows
    # this was not a real analysis.
    used_model: bool = False


def _fallback(reason: str) -> TextTriageResult:
    return TextTriageResult(
        label=None,
        reason=reason,
        confident=False,
        used_model=False,
    )


def triage(description: str) -> TextTriageResult:
    """Asks the model which known disease the description matches."""
    if not API_KEY:
        return _fallback(
            "A description alone is hard to judge. Please send a clear photo "
            "of the affected leaf."
        )

    prompt = SYSTEM_PROMPT.format(labels="\n".join(f"- {d}" for d in KNOWN_DISEASES))

    try:
        response = requests.post(
            ENDPOINT,
            params={"key": API_KEY},
            json={
                "contents": [
                    {"parts": [{"text": prompt + "\n\nFarmer says: " + description}]}
                ],
                "generationConfig": {
                    # Low temperature: this is a classification task, not
                    # a creative one.
                    "temperature": 0.1,
                    "maxOutputTokens": 200,
                    "responseMimeType": "application/json",
                },
            },
            timeout=TIMEOUT,
        )
        response.raise_for_status()
        data = response.json()
        text = data["candidates"][0]["content"]["parts"][0]["text"]
        parsed = json.loads(text)

    except Exception:
        return _fallback(
            "Could not check that just now. Please send a photo of the "
            "affected leaf instead."
        )

    label = parsed.get("label")

    # Guard against the model inventing a label outside the list. Without
    # this check a hallucinated string would flow into the app and fail
    # to resolve, or worse, resolve to the wrong thing.
    if label is not None and label not in KNOWN_DISEASES:
        return _fallback(
            "I could not match that to a disease I know. Please send a photo."
        )

    return TextTriageResult(
        label=label,
        reason=str(parsed.get("reason", ""))[:300],
        confident=bool(parsed.get("confident", False)) and label is not None,
        used_model=True,
    )
