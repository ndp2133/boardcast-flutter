// App shell with bottom navigation — 4 tabs, frosted glass nav bar
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/widget_provider.dart';
import '../state/live_activity_provider.dart';
import '../state/analytics_provider.dart';
import '../state/conditions_provider.dart';
import '../state/preferences_provider.dart';
import '../state/location_provider.dart';
import '../state/store_provider.dart';
import '../logic/scoring.dart';
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
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  DateTime? _pausedAt;

  // FL-MOTION-4: Subtle fade on tab switch
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  // Keep all tabs alive for state preservation
  final _tabs = <Widget>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      value: 1.0,
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _switchTab(int i) {
    if (i == _currentIndex) return;
    AppHaptics.nav();
    const tabs = ['Dashboard', 'Forecast', 'Sessions', 'Profile'];
    ref.read(analyticsProvider).screen(tabs[i]);
    // Quick dip to 0 then back to 1 for subtle fade
    _fadeCtrl.duration = const Duration(milliseconds: 80);
    _fadeCtrl.reverse(from: 1.0).then((_) {
      setState(() => _currentIndex = i);
      _fadeCtrl.duration = const Duration(milliseconds: 120);
      _fadeCtrl.forward(from: 0.0);
    });
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

    // FL-DR-5c: Condition-colored nav indicator
    Color navAccent = AppColors.accent;
    final condAsync = ref.watch(conditionsProvider);
    if (condAsync.hasValue) {
      final data = condAsync.value!;
      final prefs = ref.watch(preferencesProvider);
      final location = ref.watch(selectedLocationProvider);
      final now = DateTime.now();
      final currentHour = data.hourly.where((h) {
        final t = DateTime.parse(h.time);
        return t.year == now.year &&
            t.month == now.month &&
            t.day == now.day &&
            t.hour == now.hour;
      }).toList();
      if (currentHour.isNotEmpty) {
        final score = computeMatchScore(currentHour.first, prefs, location);
        if (score >= 0.8) {
          navAccent = AppColors.conditionEpic;
        } else if (score >= 0.6) {
          navAccent = AppColors.conditionGood;
        } else if (score >= 0.4) {
          navAccent = AppColors.conditionFair;
        } else {
          navAccent = AppColors.conditionPoor;
        }
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBg = isDark
        ? AppColorsDark.bgPrimary.withValues(alpha: 0.85)
        : AppColors.bgPrimary.withValues(alpha: 0.85);

    return Scaffold(
      extendBody: true,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: navBg,
              border: Border(
                top: BorderSide(
                  color: isDark ? AppColorsDark.border : AppColors.border,
                  width: 0.5,
                ),
              ),
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _switchTab,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: navAccent,
              unselectedItemColor: isDark
                  ? AppColorsDark.textTertiary
                  : AppColors.textTertiary,
              selectedFontSize: AppTypography.textXs,
              unselectedFontSize: AppTypography.textXs,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.waves_outlined),
                  activeIcon: Icon(Icons.waves),
                  label: 'Dashboard',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.timeline_outlined),
                  activeIcon: Icon(Icons.timeline),
                  label: 'Forecast',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_today_outlined),
                  activeIcon: Icon(Icons.calendar_today),
                  label: 'Sessions',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
