import 'dart:async';
import 'dart:convert';

import 'package:amenmoa_front/app/app.dart';
import 'package:amenmoa_front/app/app_shell.dart';
import 'package:amenmoa_front/features/auth/domain/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestSessionRepository implements SessionRepository {
  TestSessionRepository(this.restore);

  Future<AppSession?> Function() restore;
  int restoreCount = 0;

  @override
  Future<AppSession?> restoreSession() {
    restoreCount++;
    return restore();
  }

  @override
  Future<void> signOut() async {}
}

const splashKey = ValueKey('startup-splash');
const loginKey = ValueKey('login-screen');

Future<void> finishStartup(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows brand splash before routing a signed-out user to login', (
    tester,
  ) async {
    await tester.pumpWidget(const AmenMoaApp());

    expect(find.byKey(splashKey), findsOneWidget);
    expect(find.byKey(loginKey), findsNothing);
    expect(find.byType(AppShell), findsNothing);

    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(splashKey), findsOneWidget);

    await finishStartup(tester);
    expect(find.byKey(splashKey), findsNothing);
    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.text('아멘모아 시작하기'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('a valid restored session routes to home after the splash', (
    tester,
  ) async {
    final repository = TestSessionRepository(
      () async => AppSession(
        userId: 'verified-user',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      ),
    );
    await tester.pumpWidget(AmenMoaApp(sessionRepository: repository));
    expect(find.byKey(splashKey), findsOneWidget);

    await finishStartup(tester);
    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('혼자 시작해도, 함께'), findsOneWidget);
    expect(find.byKey(loginKey), findsNothing);
    expect(repository.restoreCount, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('an expired restored session cannot open the home screen', (
    tester,
  ) async {
    final repository = TestSessionRepository(
      () async => AppSession(
        userId: 'expired-user',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      ),
    );
    await tester.pumpWidget(AmenMoaApp(sessionRepository: repository));
    await finishStartup(tester);

    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets('keeps the splash until session restoration finishes', (
    tester,
  ) async {
    final pendingSession = Completer<AppSession?>();
    final repository = TestSessionRepository(() => pendingSession.future);
    await tester.pumpWidget(AmenMoaApp(sessionRepository: repository));
    await tester.pump(const Duration(seconds: 3));

    expect(find.byKey(splashKey), findsOneWidget);
    expect(find.byKey(loginKey), findsNothing);

    pendingSession.complete(null);
    await tester.pumpAndSettle();
    expect(find.byKey(loginKey), findsOneWidget);
  });

  testWidgets('restoration errors fall back to login and allow a retry', (
    tester,
  ) async {
    final repository = TestSessionRepository(
      () async => throw StateError('session service unavailable'),
    );
    await tester.pumpWidget(AmenMoaApp(sessionRepository: repository));
    await finishStartup(tester);

    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    repository.restore = () async => null;
    await tester.tap(find.text('다시 확인'));
    await finishStartup(tester);
    expect(repository.restoreCount, 2);
    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsNothing);
  });

  testWidgets('browsing local data does not create a persistent login', (
    tester,
  ) async {
    await tester.pumpWidget(const AmenMoaApp());
    await finishStartup(tester);
    await tester.scrollUntilVisible(
      find.text('기기 저장 모드로 둘러보기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('기기 저장 모드로 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.byType(AppShell), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    await tester.pumpWidget(const AmenMoaApp());
    await finishStartup(tester);
    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
  });

  testWidgets(
    'login actions remain reachable on a small screen with large text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 667);
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const AmenMoaApp());
      await finishStartup(tester);
      expect(find.byKey(loginKey), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('기기 저장 모드로 둘러보기'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('기기 저장 모드로 둘러보기'));
      await tester.pumpAndSettle();
      expect(find.byType(AppShell), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a stalled session check falls back to login after ten seconds', (
    tester,
  ) async {
    final pendingSession = Completer<AppSession?>();
    final repository = TestSessionRepository(() => pendingSession.future);
    await tester.pumpWidget(AmenMoaApp(sessionRepository: repository));
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(splashKey), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.text('로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.'), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    // A late service response must not bypass the login fallback.
    pendingSession.complete(null);
    await tester.pump();
    expect(find.byKey(loginKey), findsOneWidget);
  });

  testWidgets('returning from guest profile preserves saved prayer records', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'entries': jsonEncode([
        {
          'id': 'saved-prayer',
          'title': '가족의 평안',
          'seconds': 120,
          'date': DateTime.now().toIso8601String(),
          'note': '함께하는 하루',
          'kind': '개인 기도',
        },
      ]),
    });
    await tester.pumpWidget(const AmenMoaApp());
    await finishStartup(tester);
    await tester.scrollUntilVisible(
      find.text('기기 저장 모드로 둘러보기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('기기 저장 모드로 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('2분 0초'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('프로필'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('로그인 화면으로'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('로그인 화면으로'));
    await tester.pumpAndSettle();
    expect(find.byKey(loginKey), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);

    await tester.scrollUntilVisible(
      find.text('기기 저장 모드로 둘러보기'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('기기 저장 모드로 둘러보기'));
    await tester.pumpAndSettle();
    expect(find.text('2분 0초'), findsOneWidget);
    final preferences = await SharedPreferences.getInstance();
    final records = jsonDecode(preferences.getString('entries')!) as List;
    expect(records.single['id'], 'saved-prayer');
    expect(records.single['seconds'], 120);
    expect(records.single['note'], '함께하는 하루');
  });
}
