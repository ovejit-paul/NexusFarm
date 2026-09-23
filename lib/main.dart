import 'package:flutter/material.dart';

import 'core/app_theme.dart';
import 'farm/store/farm_store.dart';
import 'farm/ui/livestock_screen.dart';
import 'farm/ui/today_screen.dart';
import 'farm/ui/tools_screen.dart';
import 'screens/assistant_screen.dart';
import 'screens/profile_screen.dart';
import 'services/session.dart';

void main() async {
  // Profile, scan history and farm records are read from device storage
  // before the first frame, so the app never flashes empty then fills in.
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Session.instance.load(),
    FarmStore.instance.load(),
  ]);
  runApp(const NexusFarmApp());
}

class NexusFarmApp extends StatelessWidget {
  const NexusFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexusFarm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeShell(),
    );
  }
}

/// Five tabs. Crops and animals each have one; the Today tab brings
/// what matters from both into one list, and occasional tools sit behind
/// the Tools tab so the bar stays usable on a small phone.
///
/// IndexedStack keeps each tab alive when switching, so the diagnosis
/// feed is not lost.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Deliberately NOT const: a const list hands Flutter the identical
  // widget objects every rebuild, so Profile would never refresh its
  // scan history when you switch back to that tab.
  List<Widget> get _screens => [
        const TodayScreen(),
        const AssistantScreen(),
        const LivestockScreen(),
        const ToolsScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.15),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today, color: AppColors.primary),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.camera_alt_outlined),
            selectedIcon: Icon(Icons.camera_alt, color: AppColors.primary),
            label: 'Crop Doctor',
          ),
          NavigationDestination(
            icon: Icon(Icons.pets_outlined),
            selectedIcon: Icon(Icons.pets, color: AppColors.primary),
            label: 'Livestock',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: AppColors.primary),
            label: 'Tools',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppColors.primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
