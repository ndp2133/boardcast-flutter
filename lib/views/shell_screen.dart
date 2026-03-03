// App shell with bottom navigation — 4 tabs
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/widget_provider.dart';
import '../state/live_activity_provider.dart';
import '../state/analytics_provider.dart';
import '../state/conditions_provider.dart';
import '../state/store_provider.dart';
import '../state/auth_provider.dart';
import 'dashboard_screen.dart';
import 'forecast_screen.dart';
import 'tracking_screen.dart';
import 'history_screen.dart';

class ShellScreen extends ConsumerStatefulWidget {
  const ShellScreen({super.key});

  @override
  ConsumerState<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends ConsumerState<ShellScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  DateTime? _pausedAt;

  // Keep all tabs alive for state preservation
  final _tabs = <Widget>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_tabs.isEmpty) {
      _tabs.addAll([
        DashboardScreen(
          onNavigateToForecast: () => setState(() => _currentIndex = 1),
        ),
        const ForecastScreen(),
        const TrackingScreen(),
        const HistoryScreen(),
      ]);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final paused = _pausedAt;
      if (paused != null) {
        final elapsed = DateTime.now().difference(paused);
        if (elapsed.inHours >= 4) {
          // Data is stale — end Live Activity
          ref.read(liveActivityServiceProvider).end();
        }
        // Refresh conditions on resume
        ref.invalidate(conditionsProvider);
      }
      _pausedAt = null;

      // Sync user data + sessions from Supabase on resume
      final auth = ref.read(authServiceProvider);
      if (!auth.isGuest) {
        final store = ref.read(storeServiceProvider);
        store.syncUserData();
        store.syncSessions();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Activate widget updater — pushes conditions to home screen widget
    ref.watch(widgetUpdaterProvider);
    // Activate Live Activity updater — manages lock screen / Dynamic Island
    ref.watch(liveActivityUpdaterProvider);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: AppDurations.fast,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: IndexedStack(
          key: ValueKey(_currentIndex),
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) {
          if (i == _currentIndex) return;
          HapticFeedback.selectionClick();
          const tabs = ['Dashboard', 'Forecast', 'Track', 'History'];
          ref.read(analyticsProvider).screen(tabs[i]);
          setState(() => _currentIndex = i);
        },
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
