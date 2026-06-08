import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'services/app_settings_service.dart';
import 'services/auth_service.dart';
import 'screens/login_page.dart';
import 'screens/main_shell.dart';
import 'screens/edit_profile_page.dart';
import 'screens/notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettingsService.init();
  runApp(const MyApp());
}

/// Checks for a stored access token on startup and routes accordingly.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Defer until after the first frame so the Navigator is guaranteed ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _redirect());
  }

  Future<void> _redirect() async {
    String? token;
    try {
      token = await AuthService.getAccessToken();
    } catch (_) {
      token = null;
    }
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, token != null ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
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
            colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFFEC4899)),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Color(0xFFEC4899),
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
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthGate(),
            '/login': (context) => const LoginPage(),
            '/home': (context) => const MainShell(),
            '/edit-profile': (context) => const EditProfilePage(),
            '/notifications': (context) => const NotificationsPage(),
          },
          // Fall back to the AuthGate (which re-checks the stored token and
          // routes to /home or /login) rather than forcing the login page —
          // an unexpected route should never log an authenticated user out.
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (_) => const AuthGate(),
          ),
        );
      },
    );
  }
}
