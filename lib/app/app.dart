import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../features/auth/domain/nickname_availability.dart';
import '../features/auth/domain/session_repository.dart';
import '../features/auth/presentation/startup_gate.dart';
import 'theme/app_theme.dart';

class AmenMoaApp extends StatelessWidget {
  const AmenMoaApp({
    super.key,
    this.sessionRepository = const UnconfiguredSessionRepository(),
    this.nicknameAvailabilityChecker =
        const UnconfiguredNicknameAvailabilityChecker(),
    this.minimumSplashDuration = const Duration(milliseconds: 1600),
  });

  final SessionRepository sessionRepository;
  final NicknameAvailabilityChecker nicknameAvailabilityChecker;
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
        nicknameAvailabilityChecker: nicknameAvailabilityChecker,
        minimumSplashDuration: minimumSplashDuration,
      ),
    );
  }
}
