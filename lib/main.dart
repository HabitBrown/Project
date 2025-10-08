import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/profile_setup.dart';
import 'screens/home/home_screen.dart';

void main() => runApp(const HabitBrownApp());

class HabitBrownApp extends StatelessWidget {
  const HabitBrownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupPage(),
        '/profileSetup': (_) => const ProfileSetupPage(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
