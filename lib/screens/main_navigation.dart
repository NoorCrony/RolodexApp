import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'weekly_stats_screen.dart';
import 'gpt_plan_screen.dart';
import 'settings_screen.dart';

/// Root scaffold with a Material 3 bottom NavigationBar.
/// Each tab keeps its own navigation stack via an IndexedStack.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // Keep all screens alive so state is preserved when switching tabs
  static const List<Widget> _screens = [
    HomeScreen(),
    GptPlanScreen(),
    WeeklyStatsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // Guard against a stale index (e.g. after a hot reload that reduced tab count)
    if (_currentIndex >= _screens.length) _currentIndex = 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) =>
            setState(() => _currentIndex = index),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Prospects',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Tracker',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Summary',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
