import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/app_theme.dart';
import '../models/models.dart';
import '../services/diagnosis_service.dart';
import '../services/outbreak_service.dart';
import '../services/session.dart';
import '../widgets/outbreak_banner.dart';
import '../widgets/result_card.dart';

/// Camera, gallery and text all feed the same diagnosis flow.
/// Answers appear as cards in a scrolling feed.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _picker = ImagePicker();
  final _service = DiagnosisService();
  final _outbreaks = OutbreakService();
  final _bannerKey = GlobalKey<OutbreakBannerState>();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  final List<_Item> _feed = [];
  bool _busy = false;

  @override
  void dispose() {
    // Releases the inference backend. On mobile this closes the TFLite
    // interpreter, which would otherwise stay in memory for the life of
    // the app.
    _service.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto(ImageSource source) async {
    Uint8List bytes;
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return; // farmer cancelled
      // readAsBytes works on mobile and in the browser; XFile.path does not.
      bytes = await picked.readAsBytes();
    } catch (e) {
      // Usually a denied camera/storage permission.
      _showError('Could not open the ${source == ImageSource.camera ? 'camera' : 'gallery'}. '
          'Please check the app permissions.');
      return;
    }

    setState(() {
      _feed.add(_Item.photo(bytes));
      _busy = true;
    });
    _scrollDown();

    try {
      final result = await _service.analysePhoto(bytes);
      Session.instance.addScan(result);
      if (!mounted) return;
      setState(() {
        _feed.add(_Item.result(result));
        _busy = false;
      });
      _scrollDown();
      _contributeToDistrict(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError('Could not read that photo. Please try another one.');
    }
  }

  Future<void> _sendText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _feed.add(_Item.text(text));
      _busy = true;
    });
    _textController.clear();
    _scrollDown();

    final result = await _service.analyseText(text);
    if (!mounted) return;
    setState(() {
      _feed.add(_Item.result(result));
      _busy = false;
    });
    _scrollDown();
  }

  /// Sends a confident diagnosis towards the district outbreak count,
  /// then refreshes the banner so the farmer sees their own report
  /// reflected immediately.
  ///
  /// Follow-up requests are skipped — an unanswered question is not a
  /// finding, and counting it would inflate the district numbers.
  /// "Healthy" is skipped too; it is a real result but not an outbreak.
  Future<void> _contributeToDistrict(DiagnosisResult result) async {
    if (result.needsFollowUp) return;
    if (result.diseaseName.toLowerCase() == 'healthy') return;

    await _outbreaks.reportScan(
      district: Session.instance.district,
      crop: result.cropName,
      disease: result.diseaseName,
      confidence: result.confidence,
    );

    await _bannerKey.currentState?.refresh();
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Doctor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How this works',
            onPressed: _showModelInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          OutbreakBanner(key: _bannerKey),
          Expanded(
            child: _feed.isEmpty
                ? _empty()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _feed.length,
                    itemBuilder: (_, i) => _buildItem(_feed[i]),
                  ),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('Checking the leaf...',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          _inputBar(),
        ],
      ),
    );
  }

  /// Lets the audience (and the farmer) see whether the real trained
  /// model is running, and that it needs no internet.
  void _showModelInfo() {
    final real = _service.usingRealModel;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('How this works'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(real ? Icons.check_circle : Icons.info_outline,
                    color: real ? AppColors.success : AppColors.warning,
                    size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    real
                        ? 'Trained model loaded'
                        : 'Sample mode — model not added yet',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              '${_service.backendDescription}\n\n'
              'If it is less than 70% sure, it asks for another photo '
              'instead of naming a disease — a wrong answer would send you '
              'to buy the wrong medicine.',
              style: const TextStyle(fontSize: 14, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt_outlined,
                size: 64, color: AppColors.primaryLight),
            SizedBox(height: 16),
            Text(
              'Take a photo of the affected leaf,\nor describe what you see',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
            SizedBox(height: 10),
            _OfflineNote(),
          ],
        ),
      ),
    );
  }

  Widget _buildItem(_Item item) {
    switch (item.kind) {
      case _Kind.photo:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            constraints: const BoxConstraints(maxWidth: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(item.bytes!, fit: BoxFit.cover),
            ),
          ),
        );
      case _Kind.text:
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: const BoxConstraints(maxWidth: 280),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(item.text!,
                style: const TextStyle(color: Colors.white, fontSize: 15)),
          ),
        );
      case _Kind.result:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ResultCard(result: item.result!),
        );
    }
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.camera_alt, color: AppColors.primary),
              onPressed: _busy ? null : () => _addPhoto(ImageSource.camera),
              tooltip: 'Camera',
            ),
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.photo_library, color: AppColors.primary),
              onPressed: _busy ? null : () => _addPhoto(ImageSource.gallery),
              tooltip: 'Gallery',
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: const InputDecoration(
                  hintText: 'Describe the problem...',
                  border: InputBorder.none,
                ),
                onSubmitted: (_) => _sendText(),
              ),
            ),
            IconButton(
              iconSize: 28,
              icon: const Icon(Icons.send, color: AppColors.primary),
              onPressed: _busy ? null : _sendText,
            ),
          ],
        ),
      ),
    );
  }
}

enum _Kind { photo, text, result }

class _Item {
  final _Kind kind;
  final Uint8List? bytes;
  final String? text;
  final DiagnosisResult? result;

  _Item._(this.kind, {this.bytes, this.text, this.result});

  factory _Item.photo(Uint8List b) => _Item._(_Kind.photo, bytes: b);
  factory _Item.text(String t) => _Item._(_Kind.text, text: t);
  factory _Item.result(DiagnosisResult r) => _Item._(_Kind.result, result: r);
}

/// The "works without internet" claim is true on a phone, where the
/// model runs on-device, but not in a browser, where it calls the API.
/// Showing the wrong one would be a small lie in the interface.
class _OfflineNote extends StatelessWidget {
  const _OfflineNote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      kIsWeb ? 'Web demo — the phone app works offline' : 'Works without internet',
      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
    );
  }
}
