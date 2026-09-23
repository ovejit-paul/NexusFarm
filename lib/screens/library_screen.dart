import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/crop_data.dart';
import 'crop_detail_screen.dart';

/// The number of crops is not fixed — the grid scrolls, and search
/// plus category filters keep it usable as more crops are added.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  String? _category;

  List<String> get _categories =>
      cropLibrary.map((c) => c.category).toSet().toList();

  List<Crop> get _filtered => cropLibrary.where((crop) {
        final matchesQuery =
            crop.name.toLowerCase().contains(_query.toLowerCase());
        final matchesCategory = _category == null || crop.category == _category;
        return matchesQuery && matchesCategory;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crop Library')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search crops',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _chip('All', _category == null,
                    () => setState(() => _category = null)),
                for (final c in _categories)
                  _chip(c, _category == c, () => setState(() => _category = c)),
              ],
            ),
          ),
          Expanded(
            child: _filtered.isEmpty
                ? const Center(child: Text('No crops found'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _card(_filtered[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _card(Crop crop) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CropDetailScreen(crop: crop)),
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: crop.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: crop.color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(crop.icon, size: 46, color: crop.color),
            const SizedBox(height: 12),
            Text(
              crop.name,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '${crop.diseases.length} diseases',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
