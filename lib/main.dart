import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/supabase_service.dart';
import 'services/cache_service.dart';
import 'services/store_service.dart';
import 'services/auth_service.dart';
import 'theme/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage
  await Hive.initFlutter();

  // Initialize services
  final cacheService = CacheService();
  await cacheService.init();

  final storeService = StoreService();
  await storeService.init();

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
        _cacheServiceProvider.overrideWithValue(cacheService),
        _storeServiceProvider.overrideWithValue(storeService),
        _authServiceProvider.overrideWithValue(authService),
      ],
      child: const BoardcastApp(),
    ),
  );
}

// Override targets (unused directly — just for ProviderScope wiring)
final _cacheServiceProvider = Provider<CacheService>((_) => throw UnimplementedError());
final _storeServiceProvider = Provider<StoreService>((_) => throw UnimplementedError());
final _authServiceProvider = Provider<AuthService>((_) => throw UnimplementedError());

class BoardcastApp extends StatelessWidget {
  const BoardcastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boardcast',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
      ),
      home: const Scaffold(
        body: Center(child: Text('Boardcast — Phase 2 complete')),
      ),
    );
  }
}
