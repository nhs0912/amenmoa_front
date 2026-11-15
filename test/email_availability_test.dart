import 'dart:async';

import 'package:amenmoa_front/app/app.dart';
import 'package:amenmoa_front/features/auth/domain/email_availability.dart';
import 'package:amenmoa_front/features/auth/domain/session_repository.dart';
import 'package:amenmoa_front/features/auth/presentation/email_auth_pages.dart';
import 'package:amenmoa_front/features/auth/presentation/email_availability_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingEmailChecker implements EmailAvailabilityChecker {
  final emails = <String>[];
  final responses = <Completer<EmailAvailability>>[];
  @override
  bool get isConfigured => true;
  @override
  Future<EmailAvailability> check(String email) {
    emails.add(email);
    final response = Completer<EmailAvailability>();
    responses.add(response);
    return response.future;
  }
}

class SignupRepository implements EmailAuthRepository {
  final sentEmails = <String>[];
  @override
  bool get isConfigured => true;
  @override
  Stream<AppSession?> get sessionChanges => const Stream.empty();
  @override
  Future<AppSession?> restoreSession() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    sentEmails.add(email);
  }

  @override
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async => throw UnimplementedError();
  @override
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  }) async => throw UnimplementedError();
  @override
  Future<void> resendVerificationEmail({required String email}) async {}
}

Finder get emailInput => find.byKey(const ValueKey('email-signup-email'));
Finder get signupSubmit => find.byKey(const ValueKey('email-signup-submit'));
Finder get confirmation =>
    find.byKey(const ValueKey('email-signup-confirm-password'));

InputDecoration emailDecoration(WidgetTester tester) => tester
    .widget<TextField>(
      find.descendant(of: emailInput, matching: find.byType(TextField)),
    )
    .decoration!;

void expectStatusBorder(WidgetTester tester, Color color) {
  final decoration = emailDecoration(tester);
  expect(decoration.enabledBorder?.borderSide.color, color);
  expect(decoration.focusedBorder?.borderSide.color, color);
}

Future<void> fillPasswords(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('email-signup-password')),
    'Peaceful2026!',
  );
  await tester.enterText(confirmation, 'Peaceful2026!');
}

Future<void> pressConfirmationDone(WidgetTester tester) async {
  await tester.showKeyboard(confirmation);
  await tester.pump();
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
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

Future<void> mountSignup(
  WidgetTester tester,
  SignupRepository repository, {
  EmailAvailabilityChecker? checker,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: EmailSignUpPage(
        repository: repository,
        availabilityChecker:
            checker ?? const UnconfiguredEmailAvailabilityChecker(),
        onAuthenticated: (_) =>
            fail('Checking an address cannot authenticate a user'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> disposePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets(
    'checks only committed valid email after one second and preserves case',
    (tester) async {
      final checker = PendingEmailChecker();
      final controller = EmailAvailabilityController(checker: checker);
      controller.updateInput('not-an-email');
      await tester.pump(const Duration(seconds: 1));
      controller.updateInput('First@Example.COM', isComposing: true);
      await tester.pump(const Duration(seconds: 1));
      expect(checker.emails, isEmpty);
      expect(controller.canSubmit, isFalse);

      controller.updateInput('First@Example.COM', isComposing: false);
      await tester.pump(const Duration(milliseconds: 600));
      controller.updateInput('  Changed@Example.COM  ');
      await tester.pump(const Duration(milliseconds: 600));
      controller.updateInput('  Changed@Example.COM  ');
      await tester.pump(const Duration(milliseconds: 399));
      expect(checker.emails, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(checker.emails, ['Changed@Example.COM']);
      checker.responses.single.complete(EmailAvailability.available);
      await tester.pump();
      expect(controller.checkedEmail, 'Changed@Example.COM');
      expect(controller.canSubmit, isTrue);
      controller.dispose();
    },
  );

  testWidgets(
    'stale responses cannot replace current email and timeout can retry',
    (tester) async {
      final checker = PendingEmailChecker();
      final controller = EmailAvailabilityController(checker: checker);
      controller.updateInput('old@example.com');
      await tester.pump(const Duration(seconds: 1));
      controller.updateInput('new@example.com');
      await tester.pump(const Duration(seconds: 1));
      checker.responses[1].complete(EmailAvailability.available);
      await tester.pump();
      checker.responses[0].completeError(StateError('old test response'));
      await tester.pump();
      expect(controller.checkedEmail, 'new@example.com');
      expect(controller.canSubmit, isTrue);

      controller.updateInput('timeout@example.com');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 9999));
      expect(controller.status, EmailCheckStatus.checking);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.status, EmailCheckStatus.error);
      expect(controller.canSubmit, isFalse);
      final retry = controller.retry();
      checker.responses[3].complete(EmailAvailability.available);
      await tester.pump();
      await retry;
      expect(controller.checkedEmail, 'timeout@example.com');
      expect(controller.canSubmit, isTrue);
      checker.responses[2].complete(EmailAvailability.taken);
      await tester.pump();
      expect(controller.status, EmailCheckStatus.available);

      controller.updateInput('disposed@example.com');
      await tester.pump(const Duration(seconds: 1));
      int notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      checker.responses[4].complete(EmailAvailability.available);
      await tester.pump();
      expect(notifications, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'signup waits for an available current email before button or confirmation Enter',
    (tester) async {
      final checker = PendingEmailChecker();
      final repository = SignupRepository();
      await mountSignup(tester, repository, checker: checker);
      await tester.enterText(emailInput, 'invalid');
      await tester.pump();
      expect(emailDecoration(tester).errorText, isNotNull);
      await tester.enterText(emailInput, 'First@Example.COM');
      await tester.pump();
      expect(emailDecoration(tester).errorText, isNull);
      await fillPasswords(tester);
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      await pressConfirmationDone(tester);
      expect(repository.sentEmails, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('이메일 중복 확인 중…'), findsOneWidget);
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      await pressConfirmationDone(tester);
      expect(repository.sentEmails, isEmpty);

      checker.responses[0].complete(EmailAvailability.available);
      await tester.pumpAndSettle();
      expectStatusBorder(tester, const Color(0xFF25815F));
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNotNull);
      await tester.showKeyboard(emailInput);
      await tester.pump();
      expectStatusBorder(tester, const Color(0xFF25815F));
      await tester.enterText(emailInput, 'Other@Example.COM');
      await tester.pump();
      expect(
        emailDecoration(tester).enabledBorder?.borderSide.color,
        const Color(0xFFD6DFD8),
      );
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      checker.responses[1].complete(EmailAvailability.available);
      await tester.pumpAndSettle();
      await pressConfirmationDone(tester);
      await tester.pumpAndSettle();
      expect(repository.sentEmails, ['Other@Example.COM']);
      expect(find.byType(EmailVerificationPage), findsOneWidget);
      await disposePage(tester);
    },
  );

  testWidgets(
    'taken and failed email checks show red borders and block signup until retry',
    (tester) async {
      final checker = PendingEmailChecker();
      final repository = SignupRepository();
      await mountSignup(tester, repository, checker: checker);
      await tester.enterText(emailInput, 'taken@example.com');
      await fillPasswords(tester);
      await tester.pump(const Duration(seconds: 1));
      checker.responses[0].complete(EmailAvailability.taken);
      await tester.pump();
      expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
      expectStatusBorder(tester, const Color(0xFFBF4B45));
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      await pressConfirmationDone(tester);
      expect(repository.sentEmails, isEmpty);
      expectStatusBorder(tester, const Color(0xFFBF4B45));

      await tester.enterText(emailInput, 'retry@example.com');
      await tester.pump(const Duration(seconds: 1));
      checker.responses[1].completeError(StateError('test unavailable'));
      await tester.pump();
      expectStatusBorder(tester, const Color(0xFFBF4B45));
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      await pressConfirmationDone(tester);
      expect(repository.sentEmails, isEmpty);
      final retry = find.byKey(const ValueKey('email-availability-retry'));
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pump();
      expect(checker.emails, [
        'taken@example.com',
        'retry@example.com',
        'retry@example.com',
      ]);
      checker.responses[2].complete(EmailAvailability.available);
      await tester.pumpAndSettle();
      expectStatusBorder(tester, const Color(0xFF25815F));
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNotNull);
      await disposePage(tester);
    },
  );

  testWidgets(
    'without an email checker signup stays blocked without a false available claim',
    (tester) async {
      final repository = SignupRepository();
      await mountSignup(tester, repository);
      await tester.enterText(emailInput, 'valid@example.com');
      await fillPasswords(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('중복 확인 연결을 준비 중이에요.'), findsOneWidget);
      expect(find.text('사용할 수 있는 이메일이에요.'), findsNothing);
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      await pressConfirmationDone(tester);
      expect(repository.sentEmails, isEmpty);
      await disposePage(tester);
    },
  );

  testWidgets(
    'app checker survives login to signup and verification address editing',
    (tester) async {
      final repository = SignupRepository();
      final checker = PendingEmailChecker();
      await tester.pumpWidget(
        AmenMoaApp(
          sessionRepository: repository,
          emailAvailabilityChecker: checker,
          minimumSplashDuration: Duration.zero,
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('이메일로 로그인'));
      await tester.enterText(
        find.byKey(const ValueKey('email-login-email')),
        'Path@Example.COM',
      );
      await tapVisible(tester, find.text('처음이신가요? 이메일로 가입'));
      await tester.pump(const Duration(seconds: 1));
      expect(checker.emails, ['Path@Example.COM']);
      checker.responses[0].complete(EmailAvailability.available);
      await tester.pumpAndSettle();
      await fillPasswords(tester);
      await tapVisible(tester, signupSubmit);
      expect(find.byType(EmailVerificationPage), findsOneWidget);
      expect(repository.sentEmails, ['Path@Example.COM']);

      await tapVisible(tester, find.text('이메일 주소 수정'));
      await tester.pump(const Duration(seconds: 1));
      expect(checker.emails, ['Path@Example.COM', 'Path@Example.COM']);
      checker.responses[1].complete(EmailAvailability.taken);
      await tester.pump();
      expect(tester.widget<FilledButton>(signupSubmit).onPressed, isNull);
      expect(find.text('이미 가입된 이메일이에요.'), findsOneWidget);
      await disposePage(tester);
    },
  );
}
