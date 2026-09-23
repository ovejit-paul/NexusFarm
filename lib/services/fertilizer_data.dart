import '../models/fertilizer_models.dart';

/// Nutrient requirements, kg per hectare at MEDIUM soil fertility.
///
/// ============================================================
/// VERIFY THESE BEFORE ANYONE ACTS ON THEM.
///
/// Mid-range figures from published Bangladeshi recommendations. The
/// authoritative source is the BARC Fertilizer Recommendation Guide,
/// which also varies doses by agro-ecological zone — this table
/// collapses that dimension, so it is a starting point rather than a
/// prescription.
///
/// Wrong fertilizer advice can cost a farmer a whole season. Have an
/// agriculture faculty member or upazila agriculture officer check
/// this table before the app is used for real.
/// ============================================================
const List<FertilizerCrop> fertilizerCrops = [
  FertilizerCrop(
    name: 'Rice (Boro)',
    category: 'Cereal',
    need: NutrientNeed(nitrogen: 130, phosphorus: 25, potassium: 65, sulphur: 12),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.33),
      NitrogenSplit('15-20 days after transplanting', 0.33),
      NitrogenSplit('Just before panicle initiation', 0.34),
    ],
    note: 'Boro needs the most nitrogen of any rice season. Do not apply '
        'urea to a dry field — flood it lightly first, or much of the '
        'nitrogen escapes as gas.',
  ),
  FertilizerCrop(
    name: 'Rice (Aman)',
    category: 'Cereal',
    need: NutrientNeed(nitrogen: 90, phosphorus: 18, potassium: 45, sulphur: 10),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.33),
      NitrogenSplit('15-20 days after transplanting', 0.33),
      NitrogenSplit('Just before panicle initiation', 0.34),
    ],
    note: 'Aman gets rain, so nitrogen leaches more easily. Apply after '
        'heavy rain has passed, not before it.',
  ),
  FertilizerCrop(
    name: 'Wheat',
    category: 'Cereal',
    need: NutrientNeed(nitrogen: 110, phosphorus: 27, potassium: 55, sulphur: 15),
    nitrogenSplits: [
      NitrogenSplit('At sowing', 0.50),
      NitrogenSplit('At first irrigation, 18-21 days after sowing', 0.50),
    ],
    note: 'The second dose must go on with irrigation water. Urea on dry '
        'soil sits there and does nothing.',
  ),
  FertilizerCrop(
    name: 'Maize',
    category: 'Cereal',
    need: NutrientNeed(nitrogen: 220, phosphorus: 45, potassium: 110, sulphur: 30),
    nitrogenSplits: [
      NitrogenSplit('At sowing', 0.25),
      NitrogenSplit('At knee height, about 30 days', 0.375),
      NitrogenSplit('Just before tasselling', 0.375),
    ],
    note: 'Maize is the hungriest crop here. Splitting the urea into three '
        'matters more than the exact total.',
  ),
  FertilizerCrop(
    name: 'Potato',
    category: 'Vegetable',
    need: NutrientNeed(nitrogen: 135, phosphorus: 35, potassium: 115, sulphur: 18),
    nitrogenSplits: [
      NitrogenSplit('At planting', 0.50),
      NitrogenSplit('At earthing up, 30-35 days', 0.50),
    ],
    note: 'Potato needs unusually high potassium — it goes into the tubers. '
        'Skimping on MoP directly cuts the yield.',
  ),
  FertilizerCrop(
    name: 'Tomato',
    category: 'Vegetable',
    need: NutrientNeed(nitrogen: 110, phosphorus: 35, potassium: 70, sulphur: 15),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.34),
      NitrogenSplit('20 days after transplanting', 0.33),
      NitrogenSplit('At first flowering', 0.33),
    ],
    note: 'Too much nitrogen gives leafy plants with few fruit. Stay close '
        'to the recommended amount.',
  ),
  FertilizerCrop(
    name: 'Brinjal (eggplant)',
    category: 'Vegetable',
    need: NutrientNeed(nitrogen: 110, phosphorus: 35, potassium: 70, sulphur: 15),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.25),
      NitrogenSplit('20 days after transplanting', 0.25),
      NitrogenSplit('40 days after transplanting', 0.25),
      NitrogenSplit('60 days after transplanting', 0.25),
    ],
    note: 'Brinjal is harvested over months, so it needs feeding over '
        'months. Four small doses beat two large ones.',
  ),
  FertilizerCrop(
    name: 'Cabbage',
    category: 'Vegetable',
    need: NutrientNeed(nitrogen: 135, phosphorus: 40, potassium: 90, sulphur: 20),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.34),
      NitrogenSplit('15-20 days after transplanting', 0.33),
      NitrogenSplit('At head formation', 0.33),
    ],
  ),
  FertilizerCrop(
    name: 'Chilli',
    category: 'Vegetable',
    need: NutrientNeed(nitrogen: 90, phosphorus: 30, potassium: 60, sulphur: 15),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.34),
      NitrogenSplit('25 days after transplanting', 0.33),
      NitrogenSplit('At first fruiting', 0.33),
    ],
  ),
  FertilizerCrop(
    name: 'Onion',
    category: 'Vegetable',
    need: NutrientNeed(nitrogen: 110, phosphorus: 35, potassium: 70, sulphur: 25),
    nitrogenSplits: [
      NitrogenSplit('At final land preparation', 0.34),
      NitrogenSplit('25-30 days after planting', 0.33),
      NitrogenSplit('50-55 days after planting', 0.33),
    ],
    note: 'Onion needs a lot of sulphur — that is what gives it its '
        'pungency. Do not skip the gypsum.',
  ),
  FertilizerCrop(
    name: 'Lentil',
    category: 'Pulse',
    need: NutrientNeed(nitrogen: 22, phosphorus: 22, potassium: 35, sulphur: 12),
    nitrogenSplits: [
      NitrogenSplit('All at sowing', 1.0),
    ],
    note: 'Lentil is a legume — it fixes its own nitrogen from the air, so '
        'it needs only a small starter dose. Extra urea here is wasted '
        'money and suppresses the nitrogen-fixing bacteria.',
  ),
  FertilizerCrop(
    name: 'Mustard',
    category: 'Oilseed',
    need: NutrientNeed(nitrogen: 110, phosphorus: 32, potassium: 55, sulphur: 25),
    nitrogenSplits: [
      NitrogenSplit('At sowing', 0.50),
      NitrogenSplit('20-25 days after sowing', 0.50),
    ],
    note: 'Mustard responds strongly to sulphur — it goes into the oil. '
        'Gypsum matters as much as urea here.',
  ),
  FertilizerCrop(
    name: 'Jute',
    category: 'Fibre',
    need: NutrientNeed(nitrogen: 70, phosphorus: 18, potassium: 35, sulphur: 12),
    nitrogenSplits: [
      NitrogenSplit('At sowing', 0.34),
      NitrogenSplit('After first weeding, 20-25 days', 0.33),
      NitrogenSplit('40-45 days after sowing', 0.33),
    ],
  ),
];
