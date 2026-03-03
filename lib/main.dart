import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/supabase_service.dart';
import 'services/cache_service.dart';
import 'services/store_service.dart';
import 'services/auth_service.dart';
import 'services/widget_service.dart';
import 'services/subscription_service.dart';
import 'services/analytics_service.dart';
import 'state/conditions_provider.dart';
import 'state/store_provider.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'state/widget_provider.dart';
import 'state/subscription_provider.dart';
import 'state/analytics_provider.dart';
import 'theme/app_theme.dart';
import 'views/shell_screen.dart';
import 'views/onboarding_screen.dart';
import 'views/feature_tour_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await Hive.initFlutter();

  // Initialize services
  final cacheService = CacheService();
  await cacheService.init();

  final storeService = StoreService();
  await storeService.init();

  // Initialize home screen widget
  final widgetService = WidgetService();
  await widgetService.init();

  // Initialize Supabase
  await initSupabase();

  // Initialize auth
  final authService = AuthService(supabase);
  await authService.init();

  // Initialize subscriptions
  final subscriptionService = SubscriptionService();
  await subscriptionService.init();

  // Initialize analytics
  final analyticsService = AnalyticsService();
  await analyticsService.init();

  // Wire store to auth + supabase
  storeService.configure(
    supabase: supabase,
    getUserId: () => authService.userId,
    isGuest: () => authService.isGuest,
  );

  // Sync on auth change
  authService.onAuthChange.listen((user) async {
    if (user != null) {
      await storeService.migrateGuestData();
      await storeService.migrateGuestSessions();
      await storeService.syncSessions();
      await storeService.syncUserData();
      await subscriptionService.identify(user.id);
      analyticsService.identify(user.id);
    } else {
      await subscriptionService.reset();
      analyticsService.reset();
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        // Provide pre-initialized singletons
        cacheServiceProvider.overrideWithValue(cacheService),
        storeServiceProvider.overrideWithValue(storeService),
        authServiceProvider.overrideWithValue(authService),
        widgetServiceProvider.overrideWithValue(widgetService),
        subscriptionServiceProvider.overrideWithValue(subscriptionService),
        analyticsProvider.overrideWithValue(analyticsService),
      ],
      child: const BoardcastApp(),
    ),
  );
}

class BoardcastApp extends ConsumerWidget {
  const BoardcastApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Boardcast',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      home: const _OnboardingGate(),
    );
  }
}

class _OnboardingGate extends ConsumerStatefulWidget {
  const _OnboardingGate();

  @override
  ConsumerState<_OnboardingGate> createState() => _OnboardingGateState();
}

class _OnboardingGateState extends ConsumerState<_OnboardingGate> {
  bool? _onboarded;
  bool? _tourSeen;

  @override
  void initState() {
    super.initState();
    final store = ref.read(storeServiceProvider);
    _onboarded = store.isOnboarded;
    _tourSeen = store.isFeatureTourSeen;
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded != true) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboarded = true),
      );
    }
    if (_tourSeen != true) {
      return FeatureTourScreen(
        onComplete: () => setState(() => _tourSeen = true),
      );
    }
    return const ShellScreen();
  }
}
