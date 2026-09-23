import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/districts.dart';
import '../services/session.dart';

/// The farmer's name and district, their scan history, and a plain
/// account of what leaves the phone.
///
/// District is chosen from the official list rather than typed. It is
/// what groups outbreak reports, and a misspelling would silently split
/// one district's reports across several names.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _session = Session.instance;
  late final TextEditingController _name =
      TextEditingController(text: _session.farmerName);
  late String _district = _session.district;
  bool _dirty = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    _session.farmerName = _name.text.trim();
    _session.district = _district;
    _session.districtNeedsReview = false;
    await _session.saveProfile();
    if (!mounted) return;
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
  }

  Future<void> _pickDistrict() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DistrictPicker(current: _district),
    );
    if (picked != null && picked != _district) {
      setState(() {
        _district = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _clearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text(
          'Your past diagnoses will be removed from this phone. Reports '
          'already counted towards district warnings are not affected — '
          'they were anonymous and cannot be traced back to you.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _session.clearHistory();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final history = _session.history;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 38,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child:
                  const Icon(Icons.person, size: 38, color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Name (optional)',
              prefixIcon: Icon(Icons.badge_outlined),
              helperText: 'Only used to greet you. Never sent anywhere.',
            ),
            onChanged: (_) {
              if (!_dirty) setState(() => _dirty = true);
            },
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDistrict,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'District',
                prefixIcon: const Icon(Icons.location_on_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down),
                helperText: 'Decides which outbreak warnings you see',
                errorText: _session.districtNeedsReview && !_dirty
                    ? 'Please choose your district from the list'
                    : null,
              ),
              child: Text(
                '$_district · ${divisionOf(_district) ?? ''} division',
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _dirty ? _save : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(_dirty ? 'Save' : 'Saved'),
          ),
          const SizedBox(height: 26),
          const _PrivacyCard(),
          const SizedBox(height: 26),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'MY SCANS',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              if (history.isNotEmpty)
                TextButton.icon(
                  onPressed: _clearHistory,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'No scans yet. Diagnoses you run will be listed here.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final scan in history)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFEBEE),
                    child: Icon(Icons.coronavirus_outlined,
                        color: AppColors.danger, size: 20),
                  ),
                  title: Text(
                    scan.result.diseaseName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${scan.result.cropName} · ${scan.timeAgo}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${(scan.result.confidence * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// States exactly what the app sends, so nobody has to take privacy on
/// trust. Every line here is checked against what the code actually does.
class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    Widget row(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(text,
                    style: const TextStyle(fontSize: 13, height: 1.4)),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What leaves this phone',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 12),
            row(Icons.check_circle_outline, AppColors.success,
                'After a confident diagnosis: your district, the crop, the '
                'disease and how sure the diagnosis was. The server adds the '
                'date. Nothing else. This is what builds district warnings.'),
            row(Icons.block, AppColors.danger,
                'Never sent: your photos, your name, your location, your '
                'animals, your spray records or your ledger.'),
            row(Icons.phone_android, AppColors.textSecondary,
                'On the phone app, photos are checked on the phone itself. '
                'In the web version, a photo goes to our server for checking '
                'and is not kept.'),
          ],
        ),
      ),
    );
  }
}

/// Searchable list of the 64 districts, grouped by division.
class _DistrictPicker extends StatefulWidget {
  final String current;

  const _DistrictPicker({required this.current});

  @override
  State<_DistrictPicker> createState() => _DistrictPickerState();
}

class _DistrictPickerState extends State<_DistrictPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    // An old spelling typed into search ("bogra") still finds the district.
    final alias = normalizeDistrict(_query);
    final matches = districts
        .where((d) =>
            q.isEmpty ||
            d.name.toLowerCase().contains(q) ||
            d.division.toLowerCase().contains(q) ||
            d.name == alias)
        .toList();

    final height = MediaQuery.of(context).size.height * 0.8;

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search district or division',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? const Center(child: Text('No district matches that'))
                : ListView.builder(
                    itemCount: matches.length,
                    itemBuilder: (_, i) {
                      final d = matches[i];
                      final selected = d.name == widget.current;
                      final showHeader =
                          i == 0 || matches[i - 1].division != d.division;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader)
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 14, 16, 4),
                              child: Text(
                                '${d.division.toUpperCase()} DIVISION',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ListTile(
                            title: Text(d.name),
                            trailing: selected
                                ? const Icon(Icons.check,
                                    color: AppColors.primary)
                                : null,
                            onTap: () => Navigator.pop(context, d.name),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
