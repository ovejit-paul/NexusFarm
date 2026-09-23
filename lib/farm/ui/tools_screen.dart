import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import '../../screens/fertilizer_screen.dart';
import '../../screens/library_screen.dart';
import '../../screens/market_screen.dart';
import 'backup_screen.dart';
import 'crop_log_screen.dart';
import 'ledger_screen.dart';

/// Everything that is looked up now and then rather than every day.
class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <(IconData, String, String, Widget)>[
      (Icons.menu_book_outlined, 'Crop library',
          'Diseases, symptoms and treatments', const LibraryScreen()),
      (Icons.calculate_outlined, 'Fertilizer calculator',
          'Urea, TSP, MoP and gypsum for your field', const FertilizerScreen()),
      (Icons.sanitizer_outlined, 'Spray records',
          'Sprays and safe harvest dates', const CropLogScreen()),
      (Icons.receipt_long_outlined, 'Farm ledger',
          'Income and costs, crops and animals together', const LedgerScreen()),
      (Icons.storefront_outlined, 'Market prices',
          'Daily wholesale prices', const MarketScreen()),
      (Icons.backup_outlined, 'Backup and restore',
          'Keep a copy of your records', const BackupScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final (icon, title, sub, page) in tools)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(icon, color: AppColors.primary),
                ),
                title: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(sub),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => page)),
              ),
            ),
        ],
      ),
    );
  }
}
