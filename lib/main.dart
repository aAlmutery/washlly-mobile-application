import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'screens/customer/booking_screen.dart';
import 'screens/home_screen.dart';
import 'screens/customer/profile_screen.dart';
import 'screens/station_list_screen.dart';
import 'screens/station_map_screen.dart';
import 'screens/owner/owner_shell.dart';
import 'screens/welcome_screen.dart';
import 'state/customer_session_notifier.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(WashllyApp(sessionNotifier: CustomerSessionNotifier()));
}

class WashllyApp extends StatelessWidget {
  final CustomerSessionNotifier sessionNotifier;

  const WashllyApp({super.key, required this.sessionNotifier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sessionNotifier,
      builder: (context, _) {
        return MaterialApp(
          title: AppLocalizations.of(context)?.appTitle ?? 'Washlly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('ar'),
          home: WelcomeScreen(sessionNotifier: sessionNotifier),
          routes: {
            HomeScreen.routeName: (_) => const HomeScreen(),
            StationListScreen.routeName: (_) => const StationListScreen(),
            StationMapScreen.routeName: (_) => const StationMapScreen(),
            BookingScreen.routeName: (_) => const BookingScreen(),
            ProfileScreen.routeName: (_) => ProfileScreen(sessionNotifier: sessionNotifier),
            OwnerShell.routeName: (_) => const OwnerShell(),
          },
        );
      },
    );
  }
}
