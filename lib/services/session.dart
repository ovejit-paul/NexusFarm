import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/districts.dart';
import '../models/models.dart';

/// Holds what the app knows about this farmer.
///
/// Saved to the device so it survives closing the app. On a phone that
/// is native storage; in a browser it is localStorage. Nothing is sent
/// anywhere — the only thing that leaves the device is an anonymous
/// district-level disease report.
class Session {
  Session._();
  static final Session instance = Session._();

  static const _keyName = 'farmer_name';
  static const _keyDistrict = 'farmer_district';
  static const _keyHistory = 'scan_history';

  /// Earlier versions asked for a phone number and never used it. It is
  /// deleted from storage on load, not merely hidden.
  static const _legacyPhoneKey = 'farmer_phone';

  static const defaultDistrict = 'Dhaka';

  /// Keeps the stored history from growing without limit. A farmer
  /// scanning daily for a season would otherwise accumulate hundreds of
  /// entries nobody scrolls to.
  static const _maxHistory = 50;

  String farmerName = '';

  /// Always an official district name from [districts].
  String district = defaultDistrict;

  /// True when the stored district could not be matched to the list —
  /// typed freely in an older version — so Profile can ask for it again.
  bool districtNeedsReview = false;

  final List<SavedScan> history = [];

  SharedPreferences? _prefs;

  /// Loads saved data. Called once at startup, before the first frame.
  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();

      farmerName = _prefs!.getString(_keyName) ?? '';

      final storedDistrict = _prefs!.getString(_keyDistrict);
      if (storedDistrict != null) {
        final official = normalizeDistrict(storedDistrict);
        district = official ?? defaultDistrict;
        districtNeedsReview = official == null;
        // Rewrite old spellings ("Bogra") as the official name now, so
        // this device's reports group with everyone else's.
        if (official != null && official != storedDistrict) {
          await _prefs!.setString(_keyDistrict, official);
        }
      }

      if (_prefs!.containsKey(_legacyPhoneKey)) {
        await _prefs!.remove(_legacyPhoneKey);
      }

      final raw = _prefs!.getString(_keyHistory);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        history
          ..clear()
          ..addAll(decoded
              .map((e) => SavedScan.fromJson(e as Map<String, dynamic>)));
      }
    } catch (_) {
      // Storage unavailable or data from an older version that no longer
      // parses. Starting fresh is better than refusing to open.
    }
  }

  Future<void> saveProfile() async {
    try {
      await _prefs?.setString(_keyName, farmerName);
      await _prefs?.setString(_keyDistrict, district);
    } catch (_) {}
  }

  void addScan(DiagnosisResult result) {
    // Follow-up prompts are not diagnoses — nothing to save yet.
    if (result.needsFollowUp) return;

    history.insert(0, SavedScan(result: result, when: DateTime.now()));
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    _saveHistory();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _saveHistory();
  }

  Future<void> _saveHistory() async {
    try {
      await _prefs?.setString(
        _keyHistory,
        jsonEncode(history.map((s) => s.toJson()).toList()),
      );
    } catch (_) {}
  }
}

class SavedScan {
  final DiagnosisResult result;
  final DateTime when;

  const SavedScan({required this.result, required this.when});

  /// Short human label like "Just now" or "3h ago".
  String get timeAgo {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Map<String, dynamic> toJson() => {
        'when': when.toIso8601String(),
        'diseaseName': result.diseaseName,
        'cropName': result.cropName,
        'confidence': result.confidence,
        'symptoms': result.symptoms,
        'treatment': result.treatment,
        'preHarvestInterval': result.preHarvestInterval,
      };

  factory SavedScan.fromJson(Map<String, dynamic> json) => SavedScan(
        when: DateTime.parse(json['when'] as String),
        result: DiagnosisResult(
          diseaseName: json['diseaseName'] as String,
          cropName: json['cropName'] as String? ?? '',
          confidence: (json['confidence'] as num).toDouble(),
          symptoms: json['symptoms'] as String? ?? '',
          treatment: json['treatment'] as String? ?? '',
          preHarvestInterval: json['preHarvestInterval'] as String? ?? '',
        ),
      );
}
