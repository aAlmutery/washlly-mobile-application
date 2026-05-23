import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'screens/booking_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/station_list_screen.dart';
import 'screens/station_map_screen.dart';
import 'screens/owner_shell.dart';
import 'screens/welcome_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const WashllyApp());
}

class WashllyApp extends StatelessWidget {
  const WashllyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppLocalizations.of(context)?.appTitle ?? 'Washlly',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue.shade800),
        useMaterial3: true,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: const WelcomeScreen(),
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        StationListScreen.routeName: (_) => const StationListScreen(),
        StationMapScreen.routeName: (_) => const StationMapScreen(),
        BookingScreen.routeName: (_) => const BookingScreen(),
        ProfileScreen.routeName: (_) => const ProfileScreen(),
        OwnerShell.routeName: (_) => const OwnerShell(),
      },
    );
  }
}
