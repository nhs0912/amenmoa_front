import 'dart:async';

import 'package:amenmoa_front/app/app.dart';
import 'package:amenmoa_front/app/app_shell.dart';
import 'package:amenmoa_front/features/auth/domain/session_repository.dart';
import 'package:amenmoa_front/features/auth/presentation/email_auth_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeEmailAuthRepository implements EmailAuthRepository {
  final changes = StreamController<AppSession?>.broadcast();
  AppSession? savedSession;
  Future<AppSession?> Function()? onRestore;
  Future<AppSession> Function(String, String)? onSignIn;
  Future<void> Function(String, String)? onSignUp;
  Future<AppSession> Function(String, String)? onVerify;
  Future<void> Function(String)? onResend;
  int restoreCalls = 0;
  int signInCalls = 0;
  int signUpCalls = 0;
  int verifyCalls = 0;
  int resendCalls = 0;
  int signOutCalls = 0;

  @override
  bool get isConfigured => true;
  @override
  Stream<AppSession?> get sessionChanges => changes.stream;

  @override
  Future<AppSession?> restoreSession() async {
    restoreCalls++;
    return onRestore == null ? savedSession : onRestore!();
  }

  @override
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    final session = await onSignIn!(email, password);
    savedSession = session;
    changes.add(session);
    return session;
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    signUpCalls++;
    await onSignUp?.call(email, password);
  }

  @override
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  }) async {
    verifyCalls++;
    final session = await onVerify!(email, token);
    savedSession = session;
    changes.add(session);
    return session;
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    resendCalls++;
    await onResend?.call(email);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    savedSession = null;
    changes.add(null);
  }

  Future<void> close() => changes.close();
}

class FakeLinkEmailAuthRepository extends FakeEmailAuthRepository
    implements EmailVerificationPolicy {
  @override
  EmailVerificationMethod get emailVerificationMethod =>
      EmailVerificationMethod.link;
}

AppSession verifiedSession({Duration lifetime = const Duration(hours: 1)}) =>
    AppSession(
      userId: 'verified-email-user',
      email: 'seoyun@example.com',
      expiresAt: DateTime.now().add(lifetime),
    );

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty ||
      !tester
          .getRect(finder)
          .overlaps(
            Offset.zero &
                tester.view.physicalSize / tester.view.devicePixelRatio,
          )) {
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

Future<void> mountApp(
  WidgetTester tester,
  FakeEmailAuthRepository repository,
) async {
  await tester.pumpWidget(
    AmenMoaApp(
      sessionRepository: repository,
      minimumSplashDuration: Duration.zero,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> disposeApp(
  WidgetTester tester,
  FakeEmailAuthRepository repository,
) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await repository.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'signup requires matching credentials and verified eight digit code',
    (tester) async {
      final repository = FakeEmailAuthRepository();
      repository.onSignUp = (email, password) async {
        expect(email, 'seoyun@example.com');
        expect(password, 'Peaceful2026!');
      };
      repository.onVerify = (email, token) async {
        expect(email, 'seoyun@example.com');
        if (token != '87654321') {
          throw const AuthFailure('인증번호가 일치하지 않아요.');
        }
        return verifiedSession();
      };
      await mountApp(tester, repository);
      await tapVisible(tester, find.text('이메일로 가입'));
      expect(find.byType(EmailSignUpPage), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('email-signup-email')),
        'not-an-email',
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-password')),
        '123',
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-confirm-password')),
        '456',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-signup-submit')),
      );
      expect(repository.signUpCalls, 0);
      expect(find.byType(AppShell), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('email-signup-email')),
        'seoyun@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-password')),
        'Peaceful2026!',
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-confirm-password')),
        'Different2026!',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-signup-submit')),
      );
      expect(repository.signUpCalls, 0);

      await tester.enterText(
        find.byKey(const ValueKey('email-signup-confirm-password')),
        'Peaceful2026!',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-signup-submit')),
      );
      expect(repository.signUpCalls, 1);
      expect(find.byType(EmailVerificationPage), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(repository.savedSession, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('email-verification-token')),
        '123456',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-verification-submit')),
      );
      expect(repository.verifyCalls, 0);
      await tester.enterText(
        find.byKey(const ValueKey('email-verification-token')),
        '12345678',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-verification-submit')),
      );
      expect(find.text('인증번호가 일치하지 않아요.'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('email-verification-token')),
        '87654321',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-verification-submit')),
      );
      expect(find.byType(AppShell), findsOneWidget);
      final preferences = await SharedPreferences.getInstance();
      final storedValues = preferences.getKeys().map(preferences.get).join();
      expect(storedValues, isNot(contains('Peaceful2026!')));
      expect(storedValues, isNot(contains('87654321')));
      await disposeApp(tester, repository);
    },
  );

  testWidgets(
    'link signup checks server confirmation before opening the home screen',
    (tester) async {
      final repository = FakeLinkEmailAuthRepository();
      bool confirmed = false;
      repository.onSignUp = (email, password) async {
        expect(email, 'seoyun@example.com');
        expect(password, 'Peaceful2026!');
      };
      repository.onSignIn = (email, password) async {
        expect(email, 'seoyun@example.com');
        expect(password, 'Peaceful2026!');
        if (!confirmed) throw const AuthFailure('메일의 인증 링크를 먼저 눌러 주세요.');
        return verifiedSession();
      };
      await mountApp(tester, repository);
      await tapVisible(tester, find.text('이메일로 가입'));
      await tester.enterText(
        find.byKey(const ValueKey('email-signup-email')),
        'seoyun@example.com',
      );
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
      expect(find.byType(EmailVerificationPage), findsOneWidget);
      expect(
        find.byKey(const ValueKey('email-verification-token')),
        findsNothing,
      );
      expect(repository.savedSession, isNull);
      await tapVisible(tester, find.text('인증했어요 · 계속하기'));
      expect(find.text('메일의 인증 링크를 먼저 눌러 주세요.'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);
      expect(repository.signInCalls, 1);
      expect(repository.verifyCalls, 0);
      confirmed = true;
      await tapVisible(tester, find.text('인증했어요 · 계속하기'));
      expect(find.byType(AppShell), findsOneWidget);
      expect(repository.signInCalls, 2);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.getKeys().map(preferences.get).join(),
        isNot(contains('Peaceful2026!')),
      );
      await disposeApp(tester, repository);
    },
  );

  testWidgets(
    'link verification without a pending password offers email login',
    (tester) async {
      final repository = FakeLinkEmailAuthRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationPage(
            repository: repository,
            email: 'seoyun@example.com',
            onAuthenticated: (_) =>
                fail('Cannot authenticate without credentials'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('email-verification-token')),
        findsNothing,
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-verification-submit')),
      );
      expect(find.byType(EmailLoginPage), findsOneWidget);
      expect(repository.signInCalls, 0);
      expect(repository.verifyCalls, 0);
      await disposeApp(tester, repository);
    },
  );

  testWidgets(
    'email login errors stay on the form and successful login survives restart',
    (tester) async {
      final repository = FakeEmailAuthRepository();
      repository.onSignIn = (email, password) async {
        expect(email, 'seoyun@example.com');
        if (password != 'Peaceful2026!') {
          throw const AuthFailure('이메일 또는 비밀번호를 확인해 주세요.');
        }
        return verifiedSession();
      };
      await mountApp(tester, repository);
      await tapVisible(tester, find.text('이메일로 로그인'));
      expect(find.byType(EmailLoginPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('email-login-email')),
        'seoyun@example.com',
      );
      await tester.enterText(
        find.byKey(const ValueKey('email-login-password')),
        'Incorrect2026!',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-login-submit')),
      );
      expect(find.text('이메일 또는 비밀번호를 확인해 주세요.'), findsOneWidget);
      expect(find.byType(AppShell), findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('email-login-password')),
        'Peaceful2026!',
      );
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-login-submit')),
      );
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await mountApp(tester, repository);
      expect(find.byType(AppShell), findsOneWidget);
      expect(repository.restoreCalls, 2);
      expect(repository.signInCalls, 2);
      await disposeApp(tester, repository);
    },
  );

  testWidgets(
    'a refreshed session stays logged in across access token expiry',
    (tester) async {
      final repository = FakeEmailAuthRepository();
      repository.onRestore = () async => repository.restoreCalls == 1
          ? verifiedSession(lifetime: const Duration(seconds: 3))
          : verifiedSession();
      await mountApp(tester, repository);
      expect(find.byType(AppShell), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(repository.restoreCalls, greaterThanOrEqualTo(2));
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byKey(const ValueKey('login-screen')), findsNothing);
      await disposeApp(tester, repository);
    },
  );

  testWidgets('logout clears the session and restart returns to login', (
    tester,
  ) async {
    final repository = FakeEmailAuthRepository()
      ..savedSession = verifiedSession();
    await mountApp(tester, repository);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('프로필'),
      ),
    );
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('로그아웃'));
    final confirmation = find.byType(AlertDialog);
    if (confirmation.evaluate().isNotEmpty) {
      await tester.tap(
        find.descendant(of: confirmation, matching: find.text('로그아웃')),
      );
      await tester.pumpAndSettle();
    }
    expect(repository.signOutCalls, 1);
    expect(repository.savedSession, isNull);
    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await mountApp(tester, repository);
    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    await disposeApp(tester, repository);
  });

  testWidgets(
    'verification resend is requested without authenticating the user',
    (tester) async {
      final repository = FakeEmailAuthRepository();
      bool authenticated = false;
      repository.onResend = (email) async =>
          expect(email, 'seoyun@example.com');
      await tester.pumpWidget(
        MaterialApp(
          home: EmailVerificationPage(
            repository: repository,
            email: 'seoyun@example.com',
            onAuthenticated: (_) => authenticated = true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 61));
      await tester.pumpAndSettle();
      await tapVisible(
        tester,
        find.byKey(const ValueKey('email-verification-resend')),
      );
      expect(repository.resendCalls, 1);
      expect(authenticated, isFalse);
      expect(repository.savedSession, isNull);
      await disposeApp(tester, repository);
    },
  );
}
