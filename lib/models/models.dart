import 'package:flutter/material.dart';

/// One crop in the Crop Library.
class Crop {
  final String name;
  final String category; // Grain / Vegetable
  final IconData icon;
  final Color color;
  final List<Disease> diseases;

  const Crop({
    required this.name,
    required this.category,
    required this.icon,
    required this.color,
    required this.diseases,
  });
}

/// A disease entry: what it looks like, what causes it, what to do.
class Disease {
  final String name;
  final String symptoms;
  final String cause;
  final String treatment;

  /// How many days after spraying it is safe to harvest.
  /// Shown so farmers don't harvest treated crops too early.
  final String preHarvestInterval;

  final String severity; // low / medium / high

  const Disease({
    required this.name,
    required this.symptoms,
    required this.cause,
    required this.treatment,
    required this.preHarvestInterval,
    required this.severity,
  });
}

/// Result of analysing a photo or a text description.
///
/// When [needsFollowUp] is true the app asks another question instead
/// of showing a diagnosis — a wrong answer is worse than no answer.
class DiagnosisResult {
  final String diseaseName;
  final String cropName;
  final double confidence; // 0.0 - 1.0
  final String symptoms;
  final String treatment;
  final String preHarvestInterval;
  final bool needsFollowUp;
  final String followUpQuestion;

  const DiagnosisResult({
    required this.diseaseName,
    required this.cropName,
    required this.confidence,
    this.symptoms = '',
    this.treatment = '',
    this.preHarvestInterval = '',
    this.needsFollowUp = false,
    this.followUpQuestion = '',
  });
}
