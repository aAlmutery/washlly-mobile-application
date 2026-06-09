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
import 'state/locale_notifier.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(WashllyApp(
    sessionNotifier: CustomerSessionNotifier(),
    localeNotifier: LocaleNotifier(),
  ));
}

class WashllyApp extends StatelessWidget {
  final CustomerSessionNotifier sessionNotifier;
  final LocaleNotifier localeNotifier;

  const WashllyApp({
    super.key,
    required this.sessionNotifier,
    required this.localeNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sessionNotifier, localeNotifier]),
      builder: (context, _) {
        return MaterialApp(
          title: AppLocalizations.of(context)?.appTitle ?? 'Washlly',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: localeNotifier.locale,
          // Kurdish ('ku') uses Arabic script and is RTL, but Flutter's built-in
          // locale system doesn't recognise it as RTL. This builder covers that gap.
          builder: (context, child) {
            final lang = Localizations.localeOf(context).languageCode;
            final isRtl = lang == 'ar' || lang == 'ku';
            return Directionality(
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },
          home: WelcomeScreen(sessionNotifier: sessionNotifier),
          routes: {
            HomeScreen.routeName: (_) => const HomeScreen(),
            StationListScreen.routeName: (_) => const StationListScreen(),
            StationMapScreen.routeName: (_) => const StationMapScreen(),
            BookingScreen.routeName: (_) => const BookingScreen(),
            ProfileScreen.routeName: (_) => ProfileScreen(
              sessionNotifier: sessionNotifier,
              localeNotifier: localeNotifier,
            ),
            OwnerShell.routeName: (_) => const OwnerShell(),
          },
        );
      },
    );
  }
}
