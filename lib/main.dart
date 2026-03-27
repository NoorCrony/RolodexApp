import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/prospect_provider.dart';
import 'providers/event_provider.dart';
import 'providers/enum_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/weekly_plan_provider.dart';
import 'screens/main_navigation.dart';
import 'utils/seed_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Workmanager — wrapped in try/catch so the app still
  // launches normally if Google Drive backup isn't configured yet.
  try {
    await Workmanager().initialize(
      backgroundCallbackDispatcher,
      isInDebugMode: false,
    );
  } catch (_) {
    // Workmanager unavailable — backup scheduling disabled, app continues.
  }

  await SeedData.run();

  // Pre-load profile and Google auth state before the app renders
  final profileProvider = ProfileProvider();
  await profileProvider.load();

  final authProvider = AuthProvider();
  await authProvider.initialize();

  runApp(SalesTrackerApp(
    profileProvider: profileProvider,
    authProvider: authProvider,
  ));
}

class SalesTrackerApp extends StatelessWidget {
  final ProfileProvider profileProvider;
  final AuthProvider authProvider;

  const SalesTrackerApp({
    super.key,
    required this.profileProvider,
    required this.authProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProspectProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => EnumProvider()),
        ChangeNotifierProvider(create: (_) => WeeklyPlanProvider()),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ],
      child: MaterialApp(
        title: 'Rolodex',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
          brightness: Brightness.light,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
          cardTheme: CardThemeData(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
        home: const MainNavigation(),
      ),
    );
  }
}
