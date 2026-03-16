import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/navigator.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'app/typography.dart';
import 'screens/auth/auth.dart';
import 'screens/home/home.dart';
import 'screens/splash.dart';
import 'screens/onboarding/onboarding.dart';
import 'services/cache/local.dart';
import 'services/notification.dart';
import 'services/startup/startup.dart';
import 'services/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FirebaseMessaging.onBackgroundMessage(
    salesnoteFirebaseMessagingBackgroundHandler,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

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
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          child: MediaQuery(
            data: AppTypography.apply(mediaQuery),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      onGenerateRoute: AppRouter.onGenerateRoute,
      navigatorKey: AppNavigator.key,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<_AuthGateBootstrap> _bootstrapFuture = _loadBootstrap();

  Future<_AuthGateBootstrap> _loadBootstrap() async {
    final stopwatch = Stopwatch()..start();
    developer.log('bootstrap:start', name: 'SalesnoteBootstrap');

    developer.log('bootstrap:firebase:init', name: 'SalesnoteBootstrap');
    await Firebase.initializeApp();
    developer.log(
      'bootstrap:firebase:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );

    developer.log('bootstrap:hive:init', name: 'SalesnoteBootstrap');
    await Hive.initFlutter();
    developer.log(
      'bootstrap:hive:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );

    developer.log('bootstrap:cache:init', name: 'SalesnoteBootstrap');
    await LocalCache.init();
    developer.log(
      'bootstrap:cache:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );

    developer.log('bootstrap:warmup:start', name: 'SalesnoteBootstrap');
    await StartupWarmupService.ensureReady();
    developer.log(
      'bootstrap:warmup:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );

    developer.log('bootstrap:onboarding:read', name: 'SalesnoteBootstrap');
    final onboardingComplete = await LocalCache.isOnboardingComplete();
    developer.log(
      'bootstrap:onboarding:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );

    developer.log('bootstrap:session:read', name: 'SalesnoteBootstrap');
    final hasSession = await TokenStore().hasSessionHint();
    developer.log(
      'bootstrap:session:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );

    developer.log(
      'bootstrap:done ${stopwatch.elapsedMilliseconds}ms',
      name: 'SalesnoteBootstrap',
    );
    return _AuthGateBootstrap(
      onboardingComplete: onboardingComplete,
      hasSession: hasSession,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_AuthGateBootstrap>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen();
        }
        if (snapshot.hasError) {
          return const AuthScreen();
        }
        final data = snapshot.data;
        if (data == null) {
          return const AuthScreen();
        }
        final onboardingComplete = data.onboardingComplete;
        final hasSession = data.hasSession;
        if (hasSession) {
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

class _AuthGateBootstrap {
  const _AuthGateBootstrap({
    required this.onboardingComplete,
    required this.hasSession,
  });

  final bool onboardingComplete;
  final bool hasSession;
}
