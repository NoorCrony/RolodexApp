import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/prospect_provider.dart';
import 'providers/event_provider.dart';
import 'providers/enum_provider.dart';
import 'providers/profile_provider.dart';
import 'screens/main_navigation.dart';
import 'utils/seed_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SeedData.run();
  // Pre-load profile before the app renders
  final profileProvider = ProfileProvider();
  await profileProvider.load();
  runApp(SalesTrackerApp(profileProvider: profileProvider));
}

class SalesTrackerApp extends StatelessWidget {
  final ProfileProvider profileProvider;
  const SalesTrackerApp({super.key, required this.profileProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProspectProvider()),
        ChangeNotifierProvider(create: (_) => EventProvider()),
        ChangeNotifierProvider(create: (_) => EnumProvider()),
        ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        home: const MainNavigation(),
      ),
    );
  }
}
