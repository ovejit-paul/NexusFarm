import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../core/dates.dart';
import '../models/livestock.dart';

Color speciesColor(Species s) => switch (s) {
      Species.cattle => const Color(0xFF8D6E63),
      Species.goat => const Color(0xFF7CB342),
      Species.chicken => const Color(0xFFF9A825),
      Species.duck => const Color(0xFF29B6F6),
    };

class SectionLabel extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const SectionLabel(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.fromLTRB(0, 22, 0, 8),
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.primaryDark,
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        child: Column(
          children: [
            Icon(icon, size: 56, color: AppColors.primaryLight),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textSecondary)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      );
}

class Pill extends StatelessWidget {
  final String text;
  final Color color;

  const Pill(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
      );
}

class SpeciesAvatar extends StatelessWidget {
  final Species species;
  final double radius;

  const SpeciesAvatar(this.species, {super.key, this.radius = 22});

  @override
  Widget build(BuildContext context) => CircleAvatar(
        radius: radius,
        backgroundColor: speciesColor(species).withValues(alpha: 0.18),
        child: Text(species.emoji, style: TextStyle(fontSize: radius * 0.95)),
      );
}

/// A coloured box used for holds and warnings.
class NoticeBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? body;

  const NoticeBox({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  if (body != null) ...[
                    const SizedBox(height: 3),
                    Text(body!,
                        style: const TextStyle(fontSize: 13, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String action = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Date picker that returns a calendar day. Initial and bound dates are
/// converted to local midnight first; mixing UTC and local instants in
/// the picker's range check can reject a valid day near midnight.
Future<DateTime?> pickDay(
  BuildContext context,
  DateTime initial, {
  DateTime? first,
  DateTime? last,
}) async {
  DateTime local(DateTime d) => DateTime(d.year, d.month, d.day);
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: local(initial),
    firstDate: local(first ?? DateTime(2000)),
    lastDate: local(last ?? DateTime(now.year + 2, 12, 31)),
  );
  return picked == null ? null : dayOf(picked);
}

/// A tappable row showing a date, used in forms.
class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: const Icon(Icons.event),
            suffixIcon: value != null && onClear != null
                ? IconButton(
                    icon: const Icon(Icons.close), onPressed: onClear)
                : null,
          ),
          child: Text(value == null ? 'Not set' : formatDay(value!)),
        ),
      );
}
