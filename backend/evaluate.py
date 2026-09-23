"""
Evaluates the model exactly as the app will use it.

    python evaluate.py --model output_full/model.tflite \
                       --labels output_full/labels.txt \
                       --data merged/test

Tests the .tflite file itself — the one that ships — not the Keras model
it was converted from, so any accuracy lost in quantisation shows up
here. Images are prepared the way the phone prepares them: stretched to
224x224, RGB, values left in 0-255.

Reports three things the project's write-up previously could not:

  1. Per-class precision and recall, so it is visible which diseases are
     confused with which — early and late blight, for instance.
  2. A confusion matrix, saved as CSV.
  3. What the 70% confidence rule actually buys: at each threshold, the
     share of photos the app answers, and how often those answers are
     right. This turns the threshold from a judgement into a measurement.
"""

import argparse
import csv
import os
import sys
import time

import numpy as np
from PIL import Image

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
INPUT_SIZE = 224
THRESHOLDS = [0.0, 0.5, 0.6, 0.7, 0.8, 0.9, 0.95]


def load_interpreter(path):
    for mod in ("tflite_runtime.interpreter", "ai_edge_litert.interpreter",
                "tensorflow.lite.python.interpreter"):
        try:
            import importlib
            return importlib.import_module(mod).Interpreter(model_path=path)
        except (ImportError, AttributeError):
            continue
    raise ImportError("No TFLite interpreter available")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--labels", required=True)
    ap.add_argument("--data", required=True, help="folder of class folders")
    ap.add_argument("--limit", type=int, default=0,
                    help="max images per class (0 = all); for a quick check")
    ap.add_argument("--out", default="evaluation")
    args = ap.parse_args()

    labels = [l.strip() for l in open(args.labels) if l.strip()]
    index = {name: i for i, name in enumerate(labels)}

    itp = load_interpreter(args.model)
    itp.allocate_tensors()
    inp = itp.get_input_details()[0]
    out = itp.get_output_details()[0]
    if out["shape"][-1] != len(labels):
        print(f"ERROR: model has {out['shape'][-1]} outputs, labels.txt has "
              f"{len(labels)} lines. They come from different training runs.")
        return 1

    y_true, y_pred, conf = [], [], []
    skipped_classes = []
    start = time.time()

    for cls in sorted(os.listdir(args.data)):
        folder = os.path.join(args.data, cls)
        if not os.path.isdir(folder):
            continue
        if cls not in index:
            skipped_classes.append(cls)
            continue
        files = [f for f in sorted(os.listdir(folder))
                 if os.path.splitext(f)[1].lower() in IMAGE_EXTS]
        if args.limit:
            files = files[: args.limit]

        for f in files:
            try:
                im = Image.open(os.path.join(folder, f)).convert("RGB")
            except Exception:
                continue
            # Same as the Dart code: a plain stretch to 224x224, and no
            # division by 255 — the model normalises its own input.
            arr = np.asarray(im.resize((INPUT_SIZE, INPUT_SIZE)), dtype=np.float32)
            itp.set_tensor(inp["index"], arr[None, ...])
            itp.invoke()
            scores = itp.get_tensor(out["index"])[0]
            best = int(np.argmax(scores))
            y_true.append(index[cls])
            y_pred.append(best)
            conf.append(float(scores[best]))

    if not y_true:
        print("No images evaluated. Check --data points at class folders "
              "whose names match labels.txt.")
        return 1

    y_true, y_pred, conf = map(np.array, (y_true, y_pred, conf))
    n = len(y_true)
    elapsed = time.time() - start
    os.makedirs(args.out, exist_ok=True)

    print(f"\n{n} images, {elapsed:.0f}s "
          f"({elapsed / n * 1000:.0f} ms per image on this machine)")
    if skipped_classes:
        print(f"Skipped folders not in labels.txt: {', '.join(skipped_classes)}")

    # ---------------- overall ----------------
    acc = float((y_true == y_pred).mean())
    print(f"\nTop-1 accuracy: {acc:.4f}")

    # ---------------- per class ----------------
    present = sorted(set(y_true.tolist()))
    rows = []
    print(f"\n{'class':44s} {'n':>5s} {'precision':>9s} {'recall':>7s} {'f1':>6s}")
    for c in present:
        tp = int(((y_pred == c) & (y_true == c)).sum())
        fp = int(((y_pred == c) & (y_true != c)).sum())
        fn = int(((y_pred != c) & (y_true == c)).sum())
        p = tp / (tp + fp) if tp + fp else 0.0
        r = tp / (tp + fn) if tp + fn else 0.0
        f1 = 2 * p * r / (p + r) if p + r else 0.0
        support = int((y_true == c).sum())
        rows.append((labels[c], support, p, r, f1))
        print(f"{labels[c][:44]:44s} {support:5d} {p:9.3f} {r:7.3f} {f1:6.3f}")

    macro_f1 = float(np.mean([r[4] for r in rows]))
    print(f"\nMacro F1 (every class weighted equally): {macro_f1:.4f}")

    worst = sorted(rows, key=lambda r: r[4])[:3]
    print("Weakest classes: " + ", ".join(f"{w[0]} ({w[4]:.2f})" for w in worst))

    with open(os.path.join(args.out, "per_class.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["class", "support", "precision", "recall", "f1"])
        for r in rows:
            w.writerow([r[0], r[1], f"{r[2]:.4f}", f"{r[3]:.4f}", f"{r[4]:.4f}"])

    # ---------------- confusion matrix ----------------
    cm = np.zeros((len(labels), len(labels)), dtype=int)
    for t, p in zip(y_true, y_pred):
        cm[t, p] += 1
    with open(os.path.join(args.out, "confusion_matrix.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["true \\ predicted"] + labels)
        for i, name in enumerate(labels):
            if i in present:
                w.writerow([name] + cm[i].tolist())

    # The mistakes that matter most: pairs the model mixes up.
    confusions = []
    for i in present:
        for j in range(len(labels)):
            if i != j and cm[i, j] > 0:
                confusions.append((cm[i, j], labels[i], labels[j]))
    confusions.sort(reverse=True)
    if confusions:
        print("\nMost frequent confusions (true -> predicted):")
        for count, t, p in confusions[:5]:
            print(f"  {count:4d}  {t}  ->  {p}")

    # ---------------- the confidence threshold ----------------
    print("\nConfidence threshold — what the app would do:")
    print(f"  {'threshold':>9s} {'answers':>8s} {'right when it answers':>22s} "
          f"{'wrong answers given':>20s}")
    thr_rows = []
    for t in THRESHOLDS:
        answered = conf >= t
        cov = float(answered.mean())
        acc_ans = float((y_true[answered] == y_pred[answered]).mean()) if answered.any() else 0.0
        wrong = int(((y_true != y_pred) & answered).sum())
        thr_rows.append((t, cov, acc_ans, wrong))
        marker = "  <- app setting" if abs(t - 0.70) < 1e-9 else ""
        print(f"  {t:9.2f} {cov:8.1%} {acc_ans:22.1%} {wrong:20d}{marker}")

    with open(os.path.join(args.out, "thresholds.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["threshold", "coverage", "accuracy_when_answering", "wrong_answers"])
        for t, cov, a, wr in thr_rows:
            w.writerow([t, f"{cov:.4f}", f"{a:.4f}", wr])

    base_wrong = thr_rows[0][3]
    app_wrong = next(r[3] for r in thr_rows if abs(r[0] - 0.70) < 1e-9)
    if base_wrong:
        print(f"\nAt 0.70 the app gives {base_wrong - app_wrong} fewer wrong "
              f"answers than a model that always answers "
              f"({(base_wrong - app_wrong) / base_wrong:.0%} of its mistakes avoided), "
              f"by declining {1 - next(r[1] for r in thr_rows if abs(r[0]-0.70)<1e-9):.1%} of photos.")

    print(f"\nSaved per_class.csv, confusion_matrix.csv, thresholds.csv in {args.out}/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
