"""
Trains on the full 38-class PlantVillage dataset.

    python train_full.py --data_dir "New Plant Diseases Dataset(Augmented)"

WHY THIS SCRIPT EXISTS SEPARATELY
The augmented Kaggle dataset ships with train/ and valid/ already
separated. That separation matters enormously and must be preserved:
the augmented copies are rotations and flips of the same original
leaves, so an independent random split would put one copy of a leaf in
training and another in validation. The model would recognise leaves it
had already seen, report 99% accuracy, and be useless in a field.

This script therefore NEVER re-splits. It loads the provided folders as
given.

EXPECTED LAYOUT
    <data_dir>/
        train/
            Apple___Apple_scab/
            Apple___Black_rot/
            ... 38 folders
        valid/
            Apple___Apple_scab/
            ... the same 38 folders
"""

import argparse
import os
import sys

import tensorflow as tf
from tensorflow.keras import layers

IMAGE_SIZE = 224


def find_split_dirs(data_dir):
    """Locates train/ and valid/, allowing for the usual nesting."""
    candidates = [
        (os.path.join(data_dir, "train"), os.path.join(data_dir, "valid")),
        (os.path.join(data_dir, "train"), os.path.join(data_dir, "validation")),
    ]

    # Kaggle zips often nest the same folder name twice.
    nested = os.path.join(data_dir, os.path.basename(data_dir))
    if os.path.isdir(nested):
        candidates.insert(0, (
            os.path.join(nested, "train"),
            os.path.join(nested, "valid"),
        ))

    for train_dir, valid_dir in candidates:
        if os.path.isdir(train_dir) and os.path.isdir(valid_dir):
            return train_dir, valid_dir

    return None, None


def build_model(num_classes):
    """EfficientNet-B0 with a fresh classifier head.

    Identical to the six-class version apart from the output size, so
    the app's preprocessing stays valid: EfficientNet normalises its
    own input, which is why images are fed in as raw 0-255 values both
    here and in the Dart code.
    """
    base = tf.keras.applications.EfficientNetB0(
        input_shape=(IMAGE_SIZE, IMAGE_SIZE, 3),
        include_top=False,
        weights="imagenet",
    )
    base.trainable = False

    inputs = layers.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, 3))
    x = base(inputs, training=False)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    outputs = layers.Dense(num_classes, activation="softmax")(x)

    return tf.keras.Model(inputs, outputs), base


def export_saved_model(model, path):
    """Keras 3 moved SavedModel export to .export(); Keras 2 uses .save()."""
    if hasattr(model, "export"):
        model.export(path)
    else:
        model.save(path)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data_dir", required=True,
                    help="Folder containing train/ and valid/")
    ap.add_argument("--batch_size", type=int, default=32)
    ap.add_argument("--epochs_head", type=int, default=3)
    ap.add_argument("--epochs_finetune", type=int, default=2)
    ap.add_argument("--out", default="output_full")
    args = ap.parse_args()

    train_dir, valid_dir = find_split_dirs(args.data_dir)
    if train_dir is None:
        print(f"ERROR: could not find train/ and valid/ inside {args.data_dir}")
        print("Contents:")
        for name in sorted(os.listdir(args.data_dir))[:12]:
            print(f"  {name}")
        return 1

    print(f"train: {train_dir}")
    print(f"valid: {valid_dir}")
    print("Using the dataset's own split — NOT re-splitting.")
    print("Re-splitting augmented data would leak copies of the same leaf")
    print("into both sets and inflate the reported accuracy.\n")

    os.makedirs(args.out, exist_ok=True)

    train_ds = tf.keras.utils.image_dataset_from_directory(
        train_dir,
        image_size=(IMAGE_SIZE, IMAGE_SIZE),
        batch_size=args.batch_size,
        shuffle=True,
    )
    val_ds = tf.keras.utils.image_dataset_from_directory(
        valid_dir,
        image_size=(IMAGE_SIZE, IMAGE_SIZE),
        batch_size=args.batch_size,
        shuffle=False,
    )

    class_names = train_ds.class_names
    print(f"\n{len(class_names)} classes")

    if class_names != val_ds.class_names:
        print("ERROR: train and valid folders list different classes.")
        return 1

    labels_path = os.path.join(args.out, "labels.txt")
    with open(labels_path, "w") as f:
        f.write("\n".join(class_names))
    print(f"labels written to {labels_path}")

    auto = tf.data.AUTOTUNE

    # The dataset is already offline-augmented, so only a light flip is
    # added here. Stacking heavy augmentation on top of augmented data
    # mostly adds training time without adding variety.
    augment = tf.keras.Sequential([layers.RandomFlip("horizontal")])
    train_ds = train_ds.map(lambda x, y: (augment(x, training=True), y),
                            num_parallel_calls=auto).prefetch(auto)
    val_ds = val_ds.prefetch(auto)

    model, base = build_model(len(class_names))

    print("\n=== Stage 1: train the classifier head ===")
    model.compile(optimizer=tf.keras.optimizers.Adam(1e-3),
                  loss="sparse_categorical_crossentropy",
                  metrics=["accuracy"])
    model.fit(train_ds, validation_data=val_ds, epochs=args.epochs_head)

    print("\n=== Stage 2: fine-tune the last 20 layers ===")
    base.trainable = True
    for layer in base.layers[:-20]:
        layer.trainable = False

    model.compile(optimizer=tf.keras.optimizers.Adam(1e-5),
                  loss="sparse_categorical_crossentropy",
                  metrics=["accuracy"])
    history = model.fit(train_ds, validation_data=val_ds,
                        epochs=args.epochs_finetune)

    final_acc = history.history["val_accuracy"][-1]

    model.save(os.path.join(args.out, "model.keras"))
    saved_dir = export_saved_model(model, os.path.join(args.out, "saved_model"))

    print("\n=== Converting to TFLite ===")
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_dir)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_path = os.path.join(args.out, "model.tflite")
    with open(tflite_path, "wb") as f:
        f.write(converter.convert())

    mb = os.path.getsize(tflite_path) / (1024 * 1024)

    print("\n" + "=" * 58)
    print(f"  Classes:                   {len(class_names)}")
    print(f"  Final validation accuracy: {final_acc:.4f}  <-- write this down")
    print(f"  Model size:                {mb:.1f} MB")
    print("=" * 58)
    print(f"\nCopy into the app and the backend:")
    print(f"  {tflite_path}")
    print(f"  {labels_path}")
    print("\nThen run make_label_stubs.py to generate the 38 Dart entries.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
