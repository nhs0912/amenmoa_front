import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/domain/session_repository.dart';
import '../features/auth/presentation/startup_gate.dart';
import 'theme/app_theme.dart';

class AmenMoaApp extends StatelessWidget {
  const AmenMoaApp({
    super.key,
    this.sessionRepository = const UnconfiguredSessionRepository(),
    this.minimumSplashDuration = const Duration(milliseconds: 1600),
  });

  final SessionRepository sessionRepository;
  final Duration minimumSplashDuration;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '아멘모아',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: StartupGate(
        sessionRepository: sessionRepository,
        minimumSplashDuration: minimumSplashDuration,
      ),
    );
  }
}
