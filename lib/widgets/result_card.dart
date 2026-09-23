import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../farm/models/crop_treatment.dart';
import '../farm/ui/crop_treatment_form.dart';
import '../models/models.dart';

/// Shows either a diagnosis, or — when the model is not confident
/// enough — the follow-up question instead. Two visually distinct
/// states so a farmer can tell them apart at a glance.
class ResultCard extends StatelessWidget {
  final DiagnosisResult result;

  const ResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return result.needsFollowUp ? _followUp() : _diagnosis(context);
  }

  Widget _followUp() {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, color: AppColors.warning),
                SizedBox(width: 8),
                Text(
                  'Need one more photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              result.followUpQuestion,
              style: const TextStyle(fontSize: 15, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagnosis(BuildContext context) {
    final percent = (result.confidence * 100).round();
    final badgeColor =
        result.confidence >= 0.85 ? AppColors.success : AppColors.warning;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    result.diseaseName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$percent% sure',
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (result.cropName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'Crop: ${result.cropName}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const Divider(height: 26),
            _section('What you are seeing', result.symptoms),
            const SizedBox(height: 14),
            _section('What to do', result.treatment),
            if (result.preHarvestInterval.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule,
                        size: 18, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        result.preHarvestInterval,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Closes the loop from diagnosis to action: recording the
              // spray starts the harvest countdown on the Today screen.
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CropTreatmentForm(
                      initialCrop: result.cropName,
                      initialPhiDays: parsePhiDays(result.preHarvestInterval),
                      initialNotes: 'For ${result.diseaseName}',
                    ),
                  ),
                ),
                icon: const Icon(Icons.sanitizer_outlined, size: 18),
                label: const Text('I sprayed this — track harvest date'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String label, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryDark,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(fontSize: 15, height: 1.45)),
      ],
    );
  }
}
