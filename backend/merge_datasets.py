"""
Builds one training set from PlantVillage and the Sethy rice dataset.

    python merge_datasets.py \
        --plantvillage "New Plant Diseases Dataset(Augmented)" \
        --rice "rice-leaf-disease-image" \
        --out merged

Produces:
    merged/train/<class>/...
    merged/valid/<class>/...
    merged/test/<class>/...      rice only — see below

Files are symlinked, not copied, so this takes seconds and no extra disk.

HOW EACH SOURCE IS SPLIT, AND WHY

PlantVillage (augmented Kaggle version) arrives already split into
train/ and valid/. That split is kept exactly as given. Re-splitting an
augmented dataset scatters rotated copies of one leaf across train and
validation and inflates accuracy — the leakage already noted in the
project's limitations.

The rice dataset arrives as one folder per class, unsplit. It is split
here 70/15/15 into train/valid/test with a fixed seed — but not image by
image. Images are first grouped by a rotation- and flip-invariant
perceptual hash, allowing a few bits of difference for re-saved JPEGs, and each group goes wholly into one split. A leaf
photographed twice, or a patch saved rotated, cannot then land on both
sides of the line.

That hashing catches exact and rotated duplicates. It does not catch two
different photos of the same leaf taken from a different angle. No
automatic method can without leaf-level labels, which neither dataset has.

The rice test split is never seen during training or model selection. It
is the closest thing this project has to an honest held-out number.
"""

import argparse
import hashlib
import os
import random
import re
import sys
from collections import defaultdict

import numpy as np
from PIL import Image

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SEED = 42

# Folder names in the rice dataset vary between mirrors ("Bacterialblight",
# "Bacterial Blight", "bacterial_leaf_blight" ...). Match on keywords and
# give each class the same Crop___Disease form PlantVillage uses, so the
# app's label lookup handles them the same way.
RICE_CLASSES = [
    (re.compile(r"bacter|blight", re.I), "Rice___Bacterial_blight"),
    (re.compile(r"blast", re.I), "Rice___Blast"),
    (re.compile(r"brown", re.I), "Rice___Brown_spot"),
    (re.compile(r"tungro", re.I), "Rice___Tungro"),
]


def images_in(folder):
    for name in sorted(os.listdir(folder)):
        if os.path.splitext(name)[1].lower() in IMAGE_EXTS:
            yield os.path.join(folder, name)


def find_split_dirs(root):
    """train/ and valid/ inside PlantVillage, allowing for double nesting."""
    for base in (root, os.path.join(root, os.path.basename(root))):
        t, v = os.path.join(base, "train"), os.path.join(base, "valid")
        if os.path.isdir(t) and os.path.isdir(v):
            return t, v
    return None, None


def find_rice_classes(root):
    """Maps each rice class folder to its standard label.

    Walks down until it finds folders that match all four diseases, since
    downloaded archives often nest a level or two.
    """
    for dirpath, dirnames, _ in os.walk(root):
        mapping = {}
        for d in dirnames:
            for pattern, label in RICE_CLASSES:
                if pattern.search(d) and label not in mapping.values():
                    mapping[os.path.join(dirpath, d)] = label
                    break
        if len(mapping) == len(RICE_CLASSES):
            return mapping
    return None


HASH_SIDE = 16                      # 16x16 = 256-bit hash
_POPCOUNT = np.array([bin(i).count("1") for i in range(256)], dtype=np.uint16)


def hash_variants(path):
    """Eight 256-bit average hashes: the image in all four rotations, and
    mirrored, packed into bytes. Shape (8, 32).

    16x16 rather than the usual 8x8: rice leaves are all green with brown
    lesions, and at 8x8 distinct leaves look alike and get merged. Rotations
    use exact pixel permutations, not interpolation, so a turned copy
    hashes almost identically to the original.

    Returns None for an unreadable file.
    """
    try:
        with Image.open(path) as im:
            small = im.convert("L").resize((HASH_SIDE, HASH_SIDE), Image.BILINEAR)
    except Exception:
        return None
    ops = [None, Image.ROTATE_90, Image.ROTATE_180, Image.ROTATE_270]
    out = []
    for base in (small, small.transpose(Image.FLIP_LEFT_RIGHT)):
        for op in ops:
            img = base if op is None else base.transpose(op)
            px = np.frombuffer(img.tobytes(), dtype=np.uint8)
            out.append(np.packbits(px > px.mean()))
    return np.stack(out)


# Hashes this close (out of 256 bits) are treated as the same picture.
# Re-saving a JPEG flips a few bits; distinct leaves differ by far more.
NEAR_DUPLICATE_BITS = 20


def group_near_duplicates(files):
    """Groups files that are the same image, turned, flipped or re-saved.

    Compares every image with every other against all eight orientations,
    and joins matches with union-find. Vectorised with numpy.
    """
    hashes, readable, unreadable = [], [], []
    for f in files:
        v = hash_variants(f)
        if v is None:
            unreadable.append(f)
        else:
            hashes.append(v)
            readable.append(f)

    n = len(readable)
    parent = list(range(n))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    if n:
        allv = np.stack(hashes)                       # (n, 8, 32) uint8
        for i in range(n - 1):
            x = np.bitwise_xor(allv[i + 1:], allv[i, 0])       # (m, 8, 32)
            dist = _POPCOUNT[x].sum(axis=2).min(axis=1)        # (m,)
            for k in np.nonzero(dist <= NEAR_DUPLICATE_BITS)[0]:
                a, b = find(i), find(i + 1 + int(k))
                if a != b:
                    parent[b] = a

    groups = defaultdict(list)
    for i, f in enumerate(readable):
        groups[find(i)].append(f)
    return list(groups.values()) + [[f] for f in unreadable]


def link(src, dst_dir):
    os.makedirs(dst_dir, exist_ok=True)
    dst = os.path.join(dst_dir, os.path.basename(src))
    # Two sources can share a file name; make the link name unique.
    if os.path.exists(dst):
        stem, ext = os.path.splitext(dst)
        dst = f"{stem}_{hashlib.sha1(src.encode()).hexdigest()[:8]}{ext}"
    os.symlink(os.path.abspath(src), dst)


def split_groups(groups, fractions, rng):
    """Assigns whole groups to splits so each split gets about its share
    of images, not of groups."""
    order = list(groups)
    rng.shuffle(order)
    total = sum(len(g) for g in order)
    targets = [f * total for f in fractions]
    out = [[] for _ in fractions]
    counts = [0] * len(fractions)
    for g in order:
        # Fill the split furthest below its target.
        i = max(range(len(fractions)), key=lambda k: targets[k] - counts[k])
        out[i].extend(g)
        counts[i] += len(g)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--plantvillage", required=True)
    ap.add_argument("--rice", required=True)
    ap.add_argument("--out", default="merged")
    args = ap.parse_args()

    if os.path.exists(args.out) and os.listdir(args.out):
        print(f"ERROR: {args.out} already exists and is not empty.")
        print("Delete it first, so old links cannot mix with new ones.")
        return 1

    # ---------------- PlantVillage: keep its own split ----------------
    pv_train, pv_valid = find_split_dirs(args.plantvillage)
    if pv_train is None:
        print(f"ERROR: no train/ and valid/ found under {args.plantvillage}")
        return 1

    pv_counts = defaultdict(lambda: [0, 0])
    for split, src_root in (("train", pv_train), ("valid", pv_valid)):
        for cls in sorted(os.listdir(src_root)):
            cls_dir = os.path.join(src_root, cls)
            if not os.path.isdir(cls_dir):
                continue
            for img in images_in(cls_dir):
                link(img, os.path.join(args.out, split, cls))
                pv_counts[cls][0 if split == "train" else 1] += 1

    print(f"PlantVillage: {len(pv_counts)} classes, "
          f"{sum(c[0] for c in pv_counts.values())} train / "
          f"{sum(c[1] for c in pv_counts.values())} valid (split kept as given)")

    # ---------------- Rice: grouped split ----------------
    mapping = find_rice_classes(args.rice)
    if mapping is None:
        print(f"ERROR: could not find the four rice disease folders under {args.rice}")
        print("Expected folders mentioning: bacterial blight, blast, brown spot, tungro")
        return 1

    rng = random.Random(SEED)
    rice_summary = []
    total_dupes = 0
    largest_groups = []
    for folder, label in sorted(mapping.items(), key=lambda kv: kv[1]):
        files = list(images_in(folder))
        groups = group_near_duplicates(files)
        dupes = sum(len(g) - 1 for g in groups)
        biggest = max((len(g) for g in groups), default=0)
        total_dupes += dupes
        largest_groups.append((label, biggest))

        train, valid, test = split_groups(groups, [0.70, 0.15, 0.15], rng)
        for split, items in (("train", train), ("valid", valid), ("test", test)):
            for f in items:
                link(f, os.path.join(args.out, split, label))
        rice_summary.append((label, len(files), dupes, len(train), len(valid), len(test)))

    print(f"\nRice: {len(mapping)} classes, grouped by perceptual hash")
    print(f"  {'class':28s} {'images':>7s} {'dupes':>6s} {'train':>6s} {'valid':>6s} {'test':>6s}")
    for label, n, d, tr, va, te in rice_summary:
        print(f"  {label:28s} {n:7d} {d:6d} {tr:6d} {va:6d} {te:6d}")
    print(f"  {total_dupes} images were duplicates or rotations of another; "
          "each group was kept in a single split.")
    # A sanity check on the grouping itself: if one group swallowed a large
    # share of a class, the threshold is merging distinct leaves.
    for label, size in largest_groups:
        if size > 20:
            print(f"  WARNING: {label} has a group of {size} near-identical "
                  "images. Inspect a few; lower NEAR_DUPLICATE_BITS if they differ.")

    classes = sorted(os.listdir(os.path.join(args.out, "train")))
    print(f"\nMerged: {len(classes)} classes in {args.out}/")
    print("Next: python train_full.py --data_dir", args.out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
