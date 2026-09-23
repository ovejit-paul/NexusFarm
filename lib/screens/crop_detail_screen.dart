import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';

class CropDetailScreen extends StatelessWidget {
  final Crop crop;

  const CropDetailScreen({super.key, required this.crop});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(crop.name)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: crop.diseases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _DiseaseTile(disease: crop.diseases[i]),
      ),
    );
  }
}

class _DiseaseTile extends StatelessWidget {
  final Disease disease;

  const _DiseaseTile({required this.disease});

  Color get _severityColor {
    switch (disease.severity) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Theme(
        // Removes the default divider lines above/below an open tile.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: _severityColor.withValues(alpha: 0.15),
            child: Icon(Icons.coronavirus_outlined, color: _severityColor),
          ),
          title: Text(
            disease.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          subtitle: Text(
            '${disease.severity[0].toUpperCase()}${disease.severity.substring(1)} severity',
            style: TextStyle(color: _severityColor, fontSize: 12),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _block('Symptoms', disease.symptoms),
            _block('Cause', disease.cause),
            _block('Treatment', disease.treatment),
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
                      disease.preHarvestInterval,
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
          ],
        ),
      ),
    );
  }

  Widget _block(String label, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
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
      ),
    );
  }
}
