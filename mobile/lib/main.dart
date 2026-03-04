import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/navigator.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'screens/auth/auth.dart';
import 'screens/home/home.dart';
import 'screens/splash.dart';
import 'screens/onboarding/onboarding.dart';
import 'services/cache/local.dart';
import 'services/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  await LocalCache.init();
  runApp(const SalesNoteApp());
}

class SalesNoteApp extends StatelessWidget {
  const SalesNoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salesnote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(boldText: false),
          child: child ?? const SizedBox.shrink(),
        );
      },
      onGenerateRoute: AppRouter.onGenerateRoute,
      navigatorKey: AppNavigator.key,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        LocalCache.isOnboardingComplete(),
        TokenStore().getToken(),
      ]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        final data = snapshot.data;
        if (data == null || data.length != 2) {
          return const SplashScreen();
        }
        final onboardingComplete = data[0] as bool;
        final token = data[1] as String?;
        if (token != null && token.isNotEmpty) {
          return const HomeScreen();
        }
        if (!onboardingComplete) {
          return const OnboardingScreen();
        }
        return const AuthScreen();
      },
    );
  }
}
