import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../services/outbreak_service.dart';
import '../services/session.dart';

/// The idea that makes this more than another disease classifier:
/// scans from many farmers become one early warning for the district.
///
/// Shows nothing when no disease has crossed the reporting threshold,
/// which is the normal case. An always-visible banner would train
/// farmers to ignore it, so it only appears when there is something to
/// say.
class OutbreakBanner extends StatefulWidget {
  const OutbreakBanner({super.key});

  @override
  State<OutbreakBanner> createState() => OutbreakBannerState();
}

class OutbreakBannerState extends State<OutbreakBanner> {
  final _service = OutbreakService();

  List<Outbreak> _outbreaks = [];
  bool _dismissed = false;
  String _loadedForDistrict = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The farmer may have changed their district in Profile since this
    // was last built, so refetch when it no longer matches.
    if (_loadedForDistrict != Session.instance.district) {
      _load();
    }
  }

  /// Called after a new diagnosis so the count can update without the
  /// farmer having to reopen the screen.
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final district = Session.instance.district;
    final found = await _service.fetchOutbreaks(district);

    if (!mounted) return;
    setState(() {
      _outbreaks = found;
      _loadedForDistrict = district;
      // A new warning deserves to be seen even if an older one was
      // dismissed earlier in the session.
      if (found.isNotEmpty) _dismissed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed || _outbreaks.isEmpty) return const SizedBox.shrink();

    // Most-reported disease first — that is the one worth the space.
    final top = _outbreaks.first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.campaign_outlined,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  top.message,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (_outbreaks.length > 1) ...[
                  const SizedBox(height: 4),
                  Text(
                    '+${_outbreaks.length - 1} more warning'
                    '${_outbreaks.length > 2 ? 's' : ''} in your district',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: () => setState(() => _dismissed = true),
            child: const Icon(Icons.close,
                size: 18, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
