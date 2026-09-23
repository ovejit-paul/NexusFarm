# Pushing this to GitHub

Your repo currently holds an old 16-file copy. These commands replace it
with the full project.

## One time

```bash
cd path/to/this/folder

git init
git add -A
git commit -m "NexusFarm: offline crop disease diagnosis with confidence-aware AI"
git branch -M main
git remote add origin https://github.com/ovejit-paul/NexusFarm.git
git push -u origin main --force
```

`--force` is needed because the existing repo has a different history.
It replaces what is there, which is what you want.

If git says `remote origin already exists`, run
`git remote remove origin` first and repeat that line.

## Check before you push

```bash
git add -A
git status --porcelain | wc -l      # expect about 50
du -ch $(git diff --cached --name-only) | tail -1   # expect about 9 MB
```

If you see `plantvillage`, `output_full` or a `.zip` in the list, stop —
`.gitignore` is not being picked up and you would upload gigabytes.

## What is committed, and what is not

**Included on purpose:**
- `assets/model/model.tflite` and `backend/model/model.tflite` (4.4 MB
  each). Without them anyone cloning the repo gets sample results
  instead of a working app. At this size git handles them fine.
- All Dart and Python source, plus the documentation.

**Excluded on purpose:**
- The PlantVillage dataset — gigabytes, and freely downloadable. The
  scripts that fetch and use it are here instead.
- `android/`, `ios/`, `web/` — machine-specific. Anyone cloning runs
  `flutter create .` to regenerate them.
- `outbreaks.db` and `prices.json` — runtime data, not source.

## After pushing

Open **github.com/ovejit-paul/NexusFarm** and confirm:

1. The README renders with the metrics table at the top
2. `assets/model/model.tflite` is listed
3. The QR code on your poster now leads somewhere worth looking at

## Optional, two minutes, worth it

On the repo page, click the gear beside **About** and add:

- **Description:** Offline AI crop disease diagnosis that refuses to
  guess. 92% accuracy, 4.4 MB on-device model, Flutter + TensorFlow Lite.
- **Topics:** `flutter`, `tensorflow-lite`, `machine-learning`,
  `agriculture`, `on-device-ml`, `plant-disease-detection`, `bangladesh`

A judge who scans the QR sees that description first.
