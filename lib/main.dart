import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/supabase_service.dart';
import 'services/cache_service.dart';
import 'services/store_service.dart';
import 'services/auth_service.dart';
import 'services/widget_service.dart';
import 'state/conditions_provider.dart';
import 'state/store_provider.dart';
import 'state/auth_provider.dart';
import 'state/theme_provider.dart';
import 'state/widget_provider.dart';
import 'theme/app_theme.dart';
import 'views/shell_screen.dart';
import 'views/onboarding_screen.dart';

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

  @override
  void initState() {
    super.initState();
    final store = ref.read(storeServiceProvider);
    _onboarded = store.isOnboarded;
  }

  @override
  Widget build(BuildContext context) {
    if (_onboarded == true) {
      return const ShellScreen();
    }
    return OnboardingScreen(
      onComplete: () => setState(() => _onboarded = true),
    );
  }
}
