import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_widgets.dart';
import 'book_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'vaccine_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  static const _pages = <Widget>[
    HomeScreen(),
    VaccineScreen(),
    BookScreen(),
    ProfileScreen(),
  ];

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final destinations = [
      _Destination(Icons.home_outlined, Icons.home_rounded, l10n.t('home')),
      _Destination(Icons.vaccines_outlined, Icons.vaccines_rounded, l10n.t('vaccines')),
      _Destination(Icons.calendar_month_outlined, Icons.calendar_month_rounded, l10n.t('appointments')),
      _Destination(Icons.person_outline_rounded, Icons.person_rounded, l10n.t('profile')),
    ];

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: AppColors.border)),
              ),
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) => setState(() => _index = value),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: AppColors.tealSoft,
                useIndicator: true,
                minWidth: 86,
                leading: const Padding(
                  padding: EdgeInsets.only(top: 18, bottom: 28),
                  child: AppLogo(size: 40),
                ),
                trailing: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: IconButton(
                    tooltip: l10n.t('settings_title'),
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
                destinations: [
                  for (final destination in destinations)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon, color: AppColors.teal),
                      label: Text(destination.label),
                    ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(index: _index, children: _pages),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const _Destination(this.icon, this.selectedIcon, this.label);
}
