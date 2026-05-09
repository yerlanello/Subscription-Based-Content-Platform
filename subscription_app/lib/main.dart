import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/app_settings_service.dart';
import 'screens/login_page.dart';
import 'screens/main_shell.dart';
import 'screens/edit_profile_page.dart';
import 'screens/notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppSettingsService.themeMode,
        AppSettingsService.locale,
      ]),
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Xabarla',
          themeMode: AppSettingsService.themeMode.value,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          locale: L10n.currentLocale,
          supportedLocales: const [
            Locale('en'),
            Locale('ru'),
            Locale('kk'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/login',
          routes: {
            '/login': (context) => const LoginPage(),
            '/home': (context) => const MainShell(),
            '/edit-profile': (context) => const EditProfilePage(),
            '/notifications': (context) => const NotificationsPage(),
          },
        );
      },
    );
  }
}
