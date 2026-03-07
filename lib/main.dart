import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/supabase_service.dart';
import 'services/cache_service.dart';
import 'services/ai_limits.dart';
import 'services/store_service.dart';
import 'services/auth_service.dart';
import 'services/widget_service.dart';
import 'services/live_activity_service.dart';
import 'services/subscription_service.dart';
import 'services/analytics_service.dart';
import 'services/push_notification_service.dart';
import 'state/ai_provider.dart';
import 'state/conditions_provider.dart';
import 'state/store_provider.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'state/widget_provider.dart';
import 'state/live_activity_provider.dart';
import 'state/subscription_provider.dart';
import 'state/analytics_provider.dart';
import 'state/push_provider.dart';
import 'theme/app_theme.dart';
import 'theme/tokens.dart';
import 'theme/transitions.dart';
import 'state/strava_import_provider.dart';
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

  final aiLimitsService = AiLimitsService();
  await aiLimitsService.init();

  final storeService = StoreService();
  await storeService.init();

  // Initialize home screen widget
  final widgetService = WidgetService();
  await widgetService.init();

  // Initialize Live Activity service
  final liveActivityService = LiveActivityService();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize push notifications
  final pushService = PushNotificationService();
  await pushService.init();

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

  // Wire push service to auth + supabase
  pushService.configure(
    supabase: supabase,
    getUserId: () => authService.userId,
    isGuest: () => authService.isGuest,
    getLocationId: () => storeService.getSelectedLocationId(),
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
      await storeService.clearUserData();
      await subscriptionService.reset();
      analyticsService.reset();
    }
  });

  runApp(
    ProviderScope(
      overrides: [
        // Provide pre-initialized singletons
        cacheServiceProvider.overrideWithValue(cacheService),
        aiLimitsServiceProvider.overrideWithValue(aiLimitsService),
        storeServiceProvider.overrideWithValue(storeService),
        authServiceProvider.overrideWithValue(authService),
        widgetServiceProvider.overrideWithValue(widgetService),
        liveActivityServiceProvider.overrideWithValue(liveActivityService),
        subscriptionServiceProvider.overrideWithValue(subscriptionService),
        analyticsProvider.overrideWithValue(analyticsService),
        pushServiceProvider.overrideWithValue(pushService),
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
      scrollBehavior: const BoardcastScrollBehavior(),
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
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
    // Check if app was opened via deep link
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  void _handleDeepLink(Uri uri) {
    // Strava OAuth callback: com.boardcast.app://strava-callback?code=...&state=...
    if (uri.host == 'strava-callback') {
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      if (code != null) {
        ref
            .read(stravaImportProvider.notifier)
            .handleCallback(code, oauthState: state);
      }
      return;
    }
    // Other deep links (Supabase auth, etc.) are handled by their own listeners
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state — rebuilds on sign in/out (incl. account deletion)
    ref.watch(authStateProvider);

    final store = ref.read(storeServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              systemNavigationBarColor: AppColorsDark.bgSecondary,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              systemNavigationBarColor: AppColors.bgSecondary,
            ),
      child: _buildChild(store),
    );
  }

  Widget _buildChild(StoreService store) {
    if (!store.isOnboarded) {
      return OnboardingScreen(
        onComplete: () => setState(() {}),
      );
    }
    if (!store.isFeatureTourSeen) {
      return FeatureTourScreen(
        onComplete: () => setState(() {}),
      );
    }
    return const ShellScreen();
  }
}
