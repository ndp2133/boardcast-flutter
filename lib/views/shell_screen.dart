/// App shell with bottom navigation — 4 tabs
import 'package:flutter/material.dart';
import '../theme/tokens.dart';
import 'dashboard_screen.dart';
import 'forecast_screen.dart';
import 'tracking_screen.dart';
import 'history_screen.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          DashboardScreen(),
          ForecastScreen(),
          TrackingScreen(),
          HistoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textTertiary,
        selectedFontSize: AppTypography.textXs,
        unselectedFontSize: AppTypography.textXs,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Forecast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Track',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'History',
          ),
        ],
      ),
    );
  }
}
