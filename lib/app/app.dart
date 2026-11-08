import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_shell.dart';
import 'theme/app_theme.dart';

class AmenMoaApp extends StatelessWidget {
  const AmenMoaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '아멘모아',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AppShell(),
    );
  }
}
