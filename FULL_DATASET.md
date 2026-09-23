# Training on PlantVillage + rice

The easy way: open `backend/NexusFarm_Training.ipynb` in Google Colab and
run the cells top to bottom. This file explains what the notebook does
and why, and what to do with the results.

## The two datasets

| Dataset | Images | Classes | Kind of photo |
|---|---|---|---|
| PlantVillage, augmented (`vipoooool/new-plant-diseases-dataset`) | ~87,000 | 38 | Laboratory: one leaf, plain background |
| Rice Leaf Disease Image Samples, Sethy et al. 2020 (`nirmalsankalana/rice-leaf-disease-image`) | 5,932 | 4 | Field photos from western Odisha |

Merged: **42 classes**, including rice — Bangladesh's main food crop,
which PlantVillage does not cover at all.

## How the data is split — the part that decides whether the numbers mean anything

**PlantVillage keeps the split it came with.** Its extra images are
rotated and flipped copies of the same leaves. Splitting it again would
put copies of one leaf on both sides, and the model would score highly by
recognising leaves it had already seen.

**Rice is split 70 / 15 / 15 into train, valid and test**, but not image
by image. Every image is hashed in all eight orientations; images that
match — the same picture turned, mirrored or saved again — are grouped,
and each group goes wholly into one split. This was tested by planting
rotated, mirrored and re-saved copies: all were found, none were split
apart, and no distinct images were wrongly merged.

**The rice test split is never used in training.** It is the one honest
held-out number in this project. PlantVillage has no equivalent, because
how its Kaggle split was made is not documented.

## What the evaluation reports

`evaluate.py` tests the `.tflite` file that ships in the app, prepared
exactly the way the phone prepares images. It produces:

- **Per-class precision, recall and F1**, and the three weakest classes
- **The most frequent confusions**, e.g. early blight mistaken for late blight
- **A confusion matrix** as CSV
- **The confidence-threshold table**: at each threshold, the share of
  photos the app would answer, how often those answers are right, and how
  many wrong answers reach a farmer. The 70% setting is marked.

That last table is what turns the threshold from a judgement into a
measurement. It is worth putting on the poster and in the presentation.

## Known limits of this data

**No healthy rice class.** The rice dataset has four diseases and no
healthy leaves, so a healthy rice leaf will be pushed towards a disease.
The 70% rule catches some of these; it will not catch all. Healthy
images from another dataset were deliberately *not* mixed in: a class
drawn from a different source differs in camera and background, and the
model learns "which dataset" rather than "which disease".

**Lab photos and field photos in one model.** Every rice image is a
field photo; every other crop is a lab photo. The model may partly learn
"field-looking picture means rice". Only testing on real field photos of
potato and tomato can show whether it has.

**Near-duplicates are caught only when they are the same picture.** Two
different photographs of one leaf from different angles cannot be
detected without leaf-level labels, which neither dataset has.

## After training

The notebook ends by downloading `nexusfarm_trained.zip`. Put its files here:

| From the zip | Into the project |
|---|---|
| `output/model.tflite` | `assets/model/model.tflite` **and** `backend/model/model.tflite` |
| `output/labels.txt` | `assets/model/labels.txt` **and** `backend/model/labels.txt` |
| `label_lookup_generated.dart` | `lib/services/label_lookup.dart` (rename it) |

Both copies of the model and labels must come from the same run. Then:

```
flutter test
flutter run
```

Nothing else in the app needs changing: it reads the class count from
`labels.txt`, and the backend's text triage now reads its disease list
from the same file.

Send the full output of both evaluation cells. The README, poster
figures and presentation numbers should be updated from those, not from
the single validation figure at the end of training.
