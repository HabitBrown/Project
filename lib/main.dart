import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/login/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/profile_setup.dart';
import 'screens/home/home_screen.dart';

// 라우트용 import
import 'screens/home/potato_screen.dart';
import 'screens/home/hash_screen.dart';
import 'screens/home/habit_setting.dart';
import 'screens/home/mypage_screen.dart';
import 'screens/home/fight_setting.dart';

void main() => runApp(const HabitBrownApp());

class HabitBrownApp extends StatelessWidget {
  const HabitBrownApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
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

        // 해시내기 & 감자캐기
        // ❌ 이 줄만 지워주기 (arguments를 써야 해서)
        // '/hash': (_) => const HashScreen(hbCount: 0),
        '/potato': (_) => const PotatoScreen(hbCount: 0),

        // 습관 설정 페이지
        '/habitSetup': (_) => const HabitSetupPage(),

        // 마이페이지
        '/mypage': (_) => const MyPageScreen(),

        // ⭐ 싸우기 설정 페이지 (Fight Setting)
        '/fightSetting': (_) => const FightSettingPage(
          targetTitle: '기본 제목',
        ),
      },

      // ✅ 여기만 새로 추가
      onGenerateRoute: (settings) {
        if (settings.name == '/hash') {
          final args = settings.arguments as Map?;
          final hb = args?['hbCount'] as int? ?? 0;
          final autoOpen =
              args?['autoOpenFirstRival'] as bool? ?? false;

          return MaterialPageRoute(
            builder: (_) => HashScreen(
              hbCount: hb,
              autoOpenFirstRival: autoOpen,
            ),
          );
        }

        // 다른 라우트는 여기서 안 건드리고, null 리턴해서
        // 위에 routes: {} 설정을 그대로 사용하게 둠
        return null;
      },
    );
  }
}

