"""
Generates the Dart label_lookup entries for all 38 PlantVillage classes.

    python make_label_stubs.py --labels output_full/labels.txt

Writes label_lookup_generated.dart, ready to drop into lib/services/.

WHY THIS MATTERS
Training on 38 classes is the easy half. Without a matching entry for
each class the app falls back to "We have not written details for this
one yet" for 32 of 38 results — technically working, practically
useless.

CONTENT STATUS
Symptoms and treatments below are drawn from published agricultural
extension sources. They are a starting point, NOT verified advice.
Anything marked REVIEW NEEDED has no entry written yet and will show the
fallback text until someone fills it in.

Have an agronomist check every entry before a farmer acts on it. Wrong
chemical advice costs a season.
"""

import argparse
import os

# crop | disease | symptoms | treatment | pre-harvest interval
CONTENT = {
    "Apple___Apple_scab": (
        "Apple", "Apple Scab",
        "Olive-green to brown velvety spots on leaves and fruit. Badly hit leaves yellow and drop early.",
        "Spray a captan or mancozeb fungicide from bud break. Rake up and destroy fallen leaves — the fungus overwinters in them.",
        "Wait 7 days after spraying before harvesting."),
    "Apple___Black_rot": (
        "Apple", "Black Rot",
        "Purple flecks on leaves that widen into brown spots with purple rims. Fruit rots from the blossom end in rings.",
        "Prune out dead wood and cankers, which is where it survives. Spray captan or thiophanate-methyl at the labelled dose.",
        "Wait 14 days after spraying before harvesting."),
    "Apple___Cedar_apple_rust": (
        "Apple", "Cedar Apple Rust",
        "Bright yellow-orange spots on the upper leaf surface, later with small tubes underneath.",
        "Spray myclobutanil at pink bud stage. Remove nearby juniper or cedar where the fungus spends half its life cycle.",
        "Wait 14 days after spraying before harvesting."),
    "Apple___healthy": (
        "Apple", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the orchard as usual.", ""),

    "Blueberry___healthy": (
        "Blueberry", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),

    "Cherry_(including_sour)___Powdery_mildew": (
        "Cherry", "Powdery Mildew",
        "White powdery coating on leaves and shoots. Young leaves twist and stay small.",
        "Spray sulphur or myclobutanil early, before the coating spreads. Thin the canopy so air moves through it.",
        "Wait 7 days after spraying before harvesting."),
    "Cherry_(including_sour)___healthy": (
        "Cherry", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the orchard as usual.", ""),

    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": (
        "Maize", "Gray Leaf Spot",
        "Narrow rectangular grey-tan lesions running along the leaf veins.",
        "Spray azoxystrobin or propiconazole at first sign. Rotate away from maize next season and bury crop residue.",
        "Wait 30 days after spraying before harvesting."),
    "Corn_(maize)___Common_rust_": (
        "Maize", "Common Rust",
        "Small reddish-brown powdery pustules on both leaf surfaces. The powder rubs off on your hand.",
        "Spray propiconazole if it appears before tasselling. Late infection on a mature crop rarely needs treatment.",
        "Wait 30 days after spraying before harvesting."),
    "Corn_(maize)___Northern_Leaf_Blight": (
        "Maize", "Northern Leaf Blight",
        "Long grey-green cigar-shaped lesions, often starting on the lower leaves.",
        "Spray azoxystrobin or propiconazole. Plough in residue after harvest — the fungus survives on it.",
        "Wait 30 days after spraying before harvesting."),
    "Corn_(maize)___healthy": (
        "Maize", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),

    "Grape___Black_rot": (
        "Grape", "Black Rot",
        "Small tan leaf spots with dark borders. Berries shrivel into hard black mummies.",
        "Spray mancozeb or myclobutanil from early shoot growth. Remove mummified berries — they carry it to next season.",
        "Wait 14 days after spraying before harvesting."),
    "Grape___Esca_(Black_Measles)": (
        "Grape", "Esca (Black Measles)",
        "Yellow or red stripes between leaf veins. Berries get small dark spots. Whole vines can collapse suddenly.",
        "No effective spray exists. Cut out affected wood well below the symptoms and protect large pruning cuts.",
        ""),
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": (
        "Grape", "Leaf Blight",
        "Irregular dark brown patches on leaves, which dry and drop early.",
        "Spray mancozeb. Improve air movement by thinning shoots and keeping the canopy off the ground.",
        "Wait 14 days after spraying before harvesting."),
    "Grape___healthy": (
        "Grape", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the vineyard as usual.", ""),

    "Orange___Haunglongbing_(Citrus_greening)": (
        "Orange", "Citrus Greening (HLB)",
        "Blotchy yellow mottling that is NOT the same on both sides of the midrib. Fruit stays small, green and lopsided, and tastes bitter.",
        "There is no cure. Remove and destroy infected trees so they stop feeding the psyllid insect that spreads it, and control that insect on healthy trees. Plant only certified disease-free stock.",
        ""),

    "Peach___Bacterial_spot": (
        "Peach", "Bacterial Spot",
        "Small dark angular leaf spots that fall out leaving shot holes. Fruit gets sunken cracked pits.",
        "Spray copper early in the season, at low rates — high rates burn peach leaves. Choose tolerant varieties when replanting.",
        "Wait 7 days after spraying before harvesting."),
    "Peach___healthy": (
        "Peach", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the orchard as usual.", ""),

    "Pepper,_bell___Bacterial_spot": (
        "Bell Pepper", "Bacterial Spot",
        "Small water-soaked spots turning dark brown with yellow halos, on leaves and fruit.",
        "Spray copper with mancozeb. Use disease-free seed and avoid working among wet plants, which spreads it by hand.",
        "Wait 3 days after spraying before harvesting."),
    "Pepper,_bell___healthy": (
        "Bell Pepper", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),

    # ---- Rice (Sethy et al. 2020 dataset). Kept consistent with the
    # ---- Rice entries in lib/services/crop_data.dart.
    "Rice___Bacterial_blight": (
        "Rice", "Bacterial Leaf Blight",
        "Leaf edges turn yellow, then brown, and dry out starting from the tip. Young plants can wilt entirely.",
        "Spray copper oxychloride. Drain standing water from the field and hold back urea — drainage and less nitrogen matter more than the spray here. Choose a resistant variety next season.",
        "Wait 14 days after spraying before harvesting."),
    "Rice___Blast": (
        "Rice", "Rice Blast",
        "Eye-shaped spots on leaves — grey or white in the centre with brown edges. When it reaches the neck of the panicle, grains stay empty.",
        "Spray a tricyclazole or isoprothiolane fungicide at the dose written on the label. Do not increase the dose, and avoid heavy nitrogen, which makes blast worse.",
        "Wait 21 days after spraying before harvesting."),
    "Rice___Brown_spot": (
        "Rice", "Brown Spot",
        "Many small oval brown spots with grey centres, scattered over the leaves. Common on poor or nutrient-starved soil.",
        "Correct the soil first — brown spot usually means too little potash. Apply MoP as recommended for your field. If spots keep spreading, spray mancozeb or propiconazole at the labelled dose.",
        "Wait 21 days after spraying before harvesting."),
    "Rice___Tungro": (
        "Rice", "Tungro",
        "Leaves turn yellow to orange from the tip, plants stay short with few tillers. Patches of affected plants spread through the field.",
        "Tungro is a virus spread by the green leafhopper — no spray cures an infected plant. Pull out and destroy affected hills early, control leafhoppers while plants are young, and plant a resistant variety next season.",
        ""),
    "Potato___Early_blight": (
        "Potato", "Early Blight",
        "Dark spots with rings inside them, like a target. Appears on the older, lower leaves first.",
        "Spray mancozeb or chlorothalonil at the dose on the label. Keep the plants well watered — stressed plants get infected more easily.",
        "Wait 7 days after spraying before harvesting."),
    "Potato___Late_blight": (
        "Potato", "Late Blight",
        "Dark brown water-soaked patches on the leaves, with pale mould underneath. Spreads across a field within days in humid weather.",
        "Spray metalaxyl combined with mancozeb at the labelled dose. Remove and destroy badly infected plants.",
        "Wait 7 days after spraying before harvesting."),
    "Potato___healthy": (
        "Potato", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),

    "Raspberry___healthy": (
        "Raspberry", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),
    "Soybean___healthy": (
        "Soybean", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),

    "Squash___Powdery_mildew": (
        "Squash", "Powdery Mildew",
        "White powdery patches on leaves and stems, spreading until leaves dry out.",
        "Spray sulphur, potassium bicarbonate or myclobutanil at first sign. Do not water from overhead.",
        "Wait 3 days after spraying before harvesting."),

    "Strawberry___Leaf_scorch": (
        "Strawberry", "Leaf Scorch",
        "Many small purple spots that merge until the leaf looks burnt at the edges.",
        "Spray captan or myclobutanil. Remove old leaves after picking and space plants so they dry quickly.",
        "Wait 3 days after spraying before harvesting."),
    "Strawberry___healthy": (
        "Strawberry", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),

    "Tomato___Bacterial_spot": (
        "Tomato", "Bacterial Spot",
        "Small dark water-soaked spots with yellow rings around them, on leaves and fruit.",
        "Spray a copper-based product. Water at the base of the plant, not from above, and use clean seed.",
        "Wait 3 days after spraying before harvesting."),
    "Tomato___Early_blight": (
        "Tomato", "Early Blight",
        "Brown circular spots with rings, on the lower leaves first. Leaves yellow and drop.",
        "Spray mancozeb at the labelled dose. Remove affected leaves and do not compost them.",
        "Wait 5 days after spraying before harvesting."),
    "Tomato___Late_blight": (
        "Tomato", "Late Blight",
        "Large dark water-soaked patches on leaves and stems, spreading quickly in cool humid weather.",
        "Spray metalaxyl with mancozeb straight away. Remove infected plants — this disease can take a whole field in days.",
        "Wait 7 days after spraying before harvesting."),
    "Tomato___Leaf_Mold": (
        "Tomato", "Leaf Mould",
        "Pale yellow patches on the upper leaf surface with olive-green velvety mould directly underneath.",
        "Spray chlorothalonil or mancozeb. Increase ventilation — this one thrives in still, humid air under cover.",
        "Wait 5 days after spraying before harvesting."),
    "Tomato___Septoria_leaf_spot": (
        "Tomato", "Septoria Leaf Spot",
        "Many small circular spots with grey centres and dark borders, starting low on the plant.",
        "Spray chlorothalonil or mancozeb. Mulch the soil surface to stop spores splashing up onto the leaves.",
        "Wait 5 days after spraying before harvesting."),
    "Tomato___Spider_mites Two-spotted_spider_mite": (
        "Tomato", "Two-Spotted Spider Mite",
        "Fine pale speckling on leaves, with delicate webbing underneath. Leaves turn bronze and dry.",
        "This is a mite, not a disease — fungicide will not help. Spray abamectin or a miticide, or use insecticidal soap for a light attack. Mites build up fastest in hot dry conditions.",
        "Wait 3 days after spraying before harvesting."),
    "Tomato___Target_Spot": (
        "Tomato", "Target Spot",
        "Brown spots with concentric rings on leaves, stems and fruit. Can look like early blight.",
        "Spray chlorothalonil or azoxystrobin. Remove lower leaves touching the soil.",
        "Wait 5 days after spraying before harvesting."),
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": (
        "Tomato", "Yellow Leaf Curl Virus",
        "Leaves curl upward, turn yellow at the edges and stay small. Plants stop growing and set little fruit.",
        "No spray cures a virus. Remove infected plants immediately and control whitefly, which carries it. Use resistant varieties and protect young seedlings under net.",
        ""),
    "Tomato___Tomato_mosaic_virus": (
        "Tomato", "Mosaic Virus",
        "Light and dark green mottling on leaves, which may be narrow or puckered.",
        "No spray cures a virus. Remove infected plants and wash hands and tools — it spreads by touch. Do not smoke near tomatoes; it survives in tobacco.",
        ""),
    "Tomato___healthy": (
        "Tomato", "Healthy",
        "No disease found on this leaf.",
        "No treatment needed. Keep watching the field as usual.", ""),
}


def dart_escape(text):
    return text.replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")


def wrap(text, indent, width=68):
    """Breaks a long string into adjacent Dart string literals."""
    words = text.split()
    lines, current = [], ""
    for word in words:
        if len(current) + len(word) + 1 > width:
            lines.append(current)
            current = word
        else:
            current = f"{current} {word}".strip()
    if current:
        lines.append(current)

    pad = " " * indent
    return f"\n{pad}".join(f"'{dart_escape(l)} '" for l in lines[:-1]
                           ) + (f"\n{pad}" if len(lines) > 1 else "") + \
           f"'{dart_escape(lines[-1])}'"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--labels", required=True, help="labels.txt from training")
    ap.add_argument("--out", default="label_lookup_generated.dart")
    args = ap.parse_args()

    with open(args.labels) as f:
        labels = [line.strip() for line in f if line.strip()]

    print(f"{len(labels)} classes in {args.labels}")

    missing = [l for l in labels if l not in CONTENT]
    if missing:
        print(f"\n{len(missing)} class(es) have no content written:")
        for m in missing:
            print(f"   REVIEW NEEDED: {m}")

    covered = len(labels) - len(missing)
    print(f"\n{covered}/{len(labels)} classes have content.\n")

    out = [
        "// GENERATED by make_label_stubs.py — do not edit by hand.",
        "// Regenerate after retraining with a different class set.",
        "//",
        "// Symptoms and treatments come from published agricultural extension",
        "// sources. They have NOT been verified by an agronomist. Wrong",
        "// chemical advice costs a farmer a season — have this reviewed",
        "// before anyone acts on it.",
        "",
        "class DiseaseInfo {",
        "  final String crop;",
        "  final String disease;",
        "  final String symptoms;",
        "  final String treatment;",
        "  final String preHarvest;",
        "",
        "  const DiseaseInfo({",
        "    required this.crop,",
        "    required this.disease,",
        "    required this.symptoms,",
        "    required this.treatment,",
        "    required this.preHarvest,",
        "  });",
        "}",
        "",
        "const Map<String, DiseaseInfo> labelLookup = {",
    ]

    for label in labels:
        if label not in CONTENT:
            continue
        crop, disease, symptoms, treatment, phi = CONTENT[label]
        out.append(f"  '{dart_escape(label)}': DiseaseInfo(")
        out.append(f"    crop: '{dart_escape(crop)}',")
        out.append(f"    disease: '{dart_escape(disease)}',")
        out.append(f"    symptoms: {wrap(symptoms, 8)},")
        out.append(f"    treatment: {wrap(treatment, 8)},")
        out.append(f"    preHarvest: '{dart_escape(phi)}',")
        out.append("  ),")

    out += [
        "};",
        "",
        "/// Falls back to a readable version of the raw label when no entry",
        "/// exists yet, rather than showing the model's internal class name.",
        "DiseaseInfo lookUp(String rawLabel) {",
        "  final known = labelLookup[rawLabel];",
        "  if (known != null) return known;",
        "",
        "  final parts = rawLabel.split('___');",
        "  return DiseaseInfo(",
        "    crop: parts.isNotEmpty ? parts[0].replaceAll('_', ' ') : rawLabel,",
        "    disease: parts.length > 1 ? parts[1].replaceAll('_', ' ') : 'Unknown',",
        "    symptoms: 'We have not written details for this one yet.',",
        "    treatment:",
        "        'Please ask your local agriculture officer before applying anything.',",
        "    preHarvest: '',",
        "  );",
        "}",
        "",
    ]

    with open(args.out, "w") as f:
        f.write("\n".join(out))

    print(f"Wrote {args.out}")
    print("Copy it to lib/services/label_lookup.dart when you are happy with it.")


if __name__ == "__main__":
    main()
