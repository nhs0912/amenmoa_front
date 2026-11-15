import 'dart:async';

import 'package:amenmoa_front/app/app.dart';
import 'package:amenmoa_front/app/app_shell.dart';
import 'package:amenmoa_front/features/auth/domain/email_availability.dart';
import 'package:amenmoa_front/features/auth/domain/nickname_availability.dart';
import 'package:amenmoa_front/features/auth/domain/session_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AvailableEmailChecker implements EmailAvailabilityChecker {
  const AvailableEmailChecker();
  @override
  bool get isConfigured => true;
  @override
  Future<EmailAvailability> check(String email) async =>
      EmailAvailability.available;
}

class AvailableNicknameChecker implements NicknameAvailabilityChecker {
  const AvailableNicknameChecker();
  @override
  bool get isConfigured => true;
  @override
  Future<NicknameAvailability> check(String nickname) async =>
      NicknameAvailability.available;
}

AppSession authenticatedUser({String? nickname, String userId = 'new-user'}) =>
    AppSession(
      userId: userId,
      email: 'seoyun@example.com',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      nickname: nickname,
    );

class NicknameEmailRepository
    implements EmailAuthRepository, NicknameRepository {
  final changes = StreamController<AppSession?>.broadcast();
  AppSession? currentSession;
  bool rejectSave = false;
  int signOutCalls = 0;
  final savedNicknames = <String>[];

  @override
  bool get isConfigured => true;
  @override
  Stream<AppSession?> get sessionChanges => changes.stream;
  @override
  Future<AppSession?> restoreSession() async => currentSession;
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {}
  @override
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async => _verified();
  @override
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  }) async => _verified();
  AppSession _verified() {
    currentSession = authenticatedUser();
    changes.add(currentSession);
    return currentSession!;
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {}
  @override
  Future<AppSession> saveNickname(String nickname) async {
    savedNicknames.add(nickname);
    if (rejectSave) throw const AuthFailure('닉네임 저장이 잠시 어려워요.');
    final previous = currentSession!;
    currentSession = AppSession(
      userId: previous.userId,
      email: previous.email,
      expiresAt: previous.expiresAt,
      nickname: nickname,
    );
    changes.add(currentSession);
    return currentSession!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentSession = null;
    changes.add(null);
  }

  Future<void> close() => changes.close();
}

// No email provider API is needed to enforce the common nickname gate.
class ProviderIndependentRepository
    implements SessionRepository, NicknameRepository {
  AppSession? session = authenticatedUser(userId: 'social-account');
  String? savedNickname;
  @override
  Future<AppSession?> restoreSession() async => session;
  @override
  Future<AppSession> saveNickname(String nickname) async {
    savedNickname = nickname;
    session = authenticatedUser(userId: 'social-account', nickname: nickname);
    return session!;
  }

  @override
  Future<void> signOut() async => session = null;
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> mountApp(WidgetTester tester, SessionRepository repository) async {
  await tester.pumpWidget(
    AmenMoaApp(
      sessionRepository: repository,
      nicknameAvailabilityChecker: const AvailableNicknameChecker(),
      emailAvailabilityChecker: const AvailableEmailChecker(),
      minimumSplashDuration: Duration.zero,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> disposeApp(
  WidgetTester tester, {
  NicknameEmailRepository? repository,
}) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await repository?.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'new email verification requires a nickname before opening home',
    (tester) async {
      final repository = NicknameEmailRepository();
      await mountApp(tester, repository);
      await tapVisible(tester, find.text('이메일로 가입'));
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-email')),
        'seoyun@example.com',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-password')),
        'Peaceful2026!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-confirm-password')),
        'Peaceful2026!',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-signup-submit')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-verification-token')),
        '87654321',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-verification-submit')),
      );

      expect(find.byKey(const ValueKey('nickname-screen')), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('nickname-input')),
        '   ',
      );
      await tapVisible(tester, find.byKey(const ValueKey('nickname-submit')));
      expect(repository.savedNicknames, isEmpty);
      expect(find.byType(AppShell), findsNothing);

      repository.rejectSave = true;
      await tester.enterText(
        find.byKey(const ValueKey('nickname-input')),
        '  은혜  ',
      );
      await tester.pump(const Duration(seconds: 1));
      await tapVisible(tester, find.byKey(const ValueKey('nickname-submit')));
      expect(find.text('닉네임 저장이 잠시 어려워요.'), findsOneWidget);
      expect(find.byKey(const ValueKey('nickname-screen')), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(repository.savedNicknames.single, '은혜');

      repository.rejectSave = false;
      await tapVisible(tester, find.byKey(const ValueKey('nickname-submit')));
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byKey(const ValueKey('nickname-screen')), findsNothing);
      expect(find.textContaining('은혜님'), findsOneWidget);
      await disposeApp(tester, repository: repository);
    },
  );

  testWidgets(
    'a session from any provider must also complete nickname onboarding',
    (tester) async {
      final repository = ProviderIndependentRepository();
      await mountApp(tester, repository);
      expect(find.byKey(const ValueKey('nickname-screen')), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('nickname-input')),
        '평안',
      );
      await tester.pump(const Duration(seconds: 1));
      await tapVisible(tester, find.byKey(const ValueKey('nickname-submit')));
      expect(repository.savedNickname, '평안');
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.textContaining('평안님'), findsOneWidget);
      await disposeApp(tester);
    },
  );

  testWidgets(
    'a restored nickname skips onboarding and appears in the profile',
    (tester) async {
      final repository = NicknameEmailRepository()
        ..currentSession = authenticatedUser(nickname: '하늘');
      await mountApp(tester, repository);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byKey(const ValueKey('nickname-screen')), findsNothing);
      expect(find.textContaining('하늘님'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('프로필'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('하늘'), findsOneWidget);
      expect(find.text('seoyun@example.com'), findsOneWidget);
      expect(repository.savedNicknames, isEmpty);
      await tester.tap(find.byTooltip('닉네임 수정'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('nickname-input')),
        '기쁨',
      );
      await tester.pump(const Duration(seconds: 1));
      await tapVisible(tester, find.byKey(const ValueKey('nickname-submit')));
      expect(repository.savedNicknames.single, '기쁨');
      expect(find.text('기쁨'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('홈'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('기쁨님'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await mountApp(tester, repository);
      expect(find.byKey(const ValueKey('nickname-screen')), findsNothing);
      expect(find.textContaining('기쁨님'), findsOneWidget);
      await disposeApp(tester, repository: repository);
    },
  );

  testWidgets(
    'changing account during onboarding signs out and returns to login',
    (tester) async {
      final repository = NicknameEmailRepository()
        ..currentSession = authenticatedUser();
      await mountApp(tester, repository);
      expect(find.byKey(const ValueKey('nickname-screen')), findsOneWidget);
      await tapVisible(tester, find.text('다른 계정으로 로그인'));
      expect(repository.signOutCalls, 1);
      expect(repository.currentSession, isNull);
      expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
      expect(find.byKey(const ValueKey('nickname-screen')), findsNothing);
      expect(find.byType(AppShell), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await mountApp(tester, repository);
      expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
      await disposeApp(tester, repository: repository);
    },
  );
}
