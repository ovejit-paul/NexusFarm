import 'package:flutter/material.dart';
import '../models/models.dart';

/// Reference content for the Crop Library.
///
/// Kept in code for Phase 1 so the app has zero network dependency.
/// Phase 2 can move this to a database without changing the screens.
const List<Crop> cropLibrary = [
  Crop(
    name: 'Rice',
    category: 'Grain',
    icon: Icons.grass,
    color: Color(0xFF7CB342),
    diseases: [
      Disease(
        name: 'Rice Blast',
        symptoms:
            'Eye-shaped spots on leaves — grey or white in the centre with brown edges. Severe cases kill the whole leaf.',
        cause:
            'The fungus Magnaporthe oryzae. Spreads faster when too much nitrogen fertiliser is used.',
        treatment:
            'Spray a tricyclazole or isoprothiolane fungicide at the dose written on the label. Do not increase the dose — it does not help and harms the soil.',
        preHarvestInterval: 'Wait 21 days after spraying before harvesting.',
        severity: 'high',
      ),
      Disease(
        name: 'Bacterial Leaf Blight',
        symptoms:
            'Leaf edges turn yellow, then brown, and dry out starting from the tip.',
        cause:
            'The bacterium Xanthomonas oryzae. Spreads in waterlogged fields.',
        treatment:
            'Spray copper oxychloride. Drain standing water from the field — drainage matters more than the spray here.',
        preHarvestInterval: 'Wait 14 days after spraying before harvesting.',
        severity: 'medium',
      ),
      Disease(
        name: 'Brown Spot',
        symptoms:
            'Many small oval brown spots with grey centres, scattered over the leaves. Common on poor or nutrient-starved soil.',
        cause:
            'The fungus Bipolaris oryzae. Strongest where the soil lacks potash.',
        treatment:
            'Correct the soil first — apply MoP as recommended for your field. If spots keep spreading, spray mancozeb or propiconazole at the labelled dose.',
        preHarvestInterval: 'Wait 21 days after spraying before harvesting.',
        severity: 'medium',
      ),
      Disease(
        name: 'Tungro',
        symptoms:
            'Leaves turn yellow to orange from the tip; plants stay short with few tillers. Affected patches spread through the field.',
        cause:
            'A virus carried from plant to plant by the green leafhopper.',
        treatment:
            'No spray cures an infected plant. Pull out and destroy affected hills early, control leafhoppers while plants are young, and use a resistant variety next season.',
        preHarvestInterval:
            'No harvest wait for the disease itself. If an insecticide is used, follow its label.',
        severity: 'high',
      ),
    ],
  ),
  Crop(
    name: 'Potato',
    category: 'Vegetable',
    icon: Icons.egg,
    color: Color(0xFF8D6E63),
    diseases: [
      Disease(
        name: 'Late Blight',
        symptoms:
            'Dark brown water-soaked patches on leaves, with pale mould on the underside. Spreads across a field within days in humid weather.',
        cause:
            'Phytophthora infestans. Thrives when it is cool and humid for two days or more.',
        treatment:
            'Spray metalaxyl combined with mancozeb at the labelled dose. Remove and destroy badly infected plants.',
        preHarvestInterval: 'Wait 7 days after spraying before harvesting.',
        severity: 'high',
      ),
      Disease(
        name: 'Early Blight',
        symptoms:
            'Dark spots with rings inside them, like a target. Appears on older, lower leaves first.',
        cause: 'The fungus Alternaria solani. Common on stressed plants.',
        treatment:
            'Spray mancozeb or chlorothalonil. Keep plants well watered — stressed plants get infected more easily.',
        preHarvestInterval: 'Wait 7 days after spraying before harvesting.',
        severity: 'medium',
      ),
    ],
  ),
  Crop(
    name: 'Tomato',
    category: 'Vegetable',
    icon: Icons.local_florist,
    color: Color(0xFFE53935),
    diseases: [
      Disease(
        name: 'Early Blight',
        symptoms:
            'Brown circular spots with rings, on the lower leaves first. Leaves yellow and drop.',
        cause: 'The fungus Alternaria solani.',
        treatment:
            'Spray mancozeb at the labelled dose. Remove affected leaves and do not compost them.',
        preHarvestInterval: 'Wait 5 days after spraying before harvesting.',
        severity: 'medium',
      ),
      Disease(
        name: 'Bacterial Spot',
        symptoms:
            'Small dark water-soaked spots with yellow rings around them, on leaves and fruit.',
        cause: 'Xanthomonas bacteria. Spreads through splashing water.',
        treatment:
            'Spray a copper-based product. Water at the base of the plant, not from above.',
        preHarvestInterval: 'Wait 3 days after spraying before harvesting.',
        severity: 'medium',
      ),
    ],
  ),
  Crop(
    name: 'Wheat',
    category: 'Grain',
    icon: Icons.spa,
    color: Color(0xFFFBC02D),
    diseases: [
      Disease(
        name: 'Wheat Rust',
        symptoms:
            'Reddish-brown powdery spots on leaves and stems. The powder rubs off on your hand.',
        cause: 'Puccinia fungus species. Carried long distances by wind.',
        treatment:
            'Spray propiconazole at the labelled dose, early — rust spreads very fast once established.',
        preHarvestInterval: 'Wait 35 days after spraying before harvesting.',
        severity: 'high',
      ),
    ],
  ),
];
