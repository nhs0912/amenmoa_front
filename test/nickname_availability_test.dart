import 'dart:async';

import 'package:amenmoa_front/app/app.dart';
import 'package:amenmoa_front/features/auth/domain/nickname_availability.dart';
import 'package:amenmoa_front/features/auth/domain/session_repository.dart';
import 'package:amenmoa_front/features/auth/presentation/nickname_availability_controller.dart';
import 'package:amenmoa_front/features/auth/presentation/nickname_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PendingNicknameChecker implements NicknameAvailabilityChecker {
  final names = <String>[];
  final responses = <Completer<NicknameAvailability>>[];
  @override
  bool get isConfigured => true;
  @override
  Future<NicknameAvailability> check(String nickname) {
    names.add(nickname);
    final response = Completer<NicknameAvailability>();
    responses.add(response);
    return response.future;
  }
}

AppSession savedSession(String nickname) => AppSession(
  userId: 'verified-user',
  expiresAt: DateTime.now().add(const Duration(hours: 1)),
  nickname: nickname,
);

class NicknameGateRepository implements SessionRepository, NicknameRepository {
  int saveCalls = 0;
  @override
  Future<AppSession?> restoreSession() async => AppSession(
    userId: 'verified-user',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  @override
  Future<AppSession> saveNickname(String nickname) async {
    saveCalls++;
    return savedSession(nickname);
  }

  @override
  Future<void> signOut() async {}
}

Finder get input => find.byKey(const ValueKey('nickname-input'));
Finder get submit => find.byKey(const ValueKey('nickname-submit'));

Future<void> disposePage(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

void main() {
  testWidgets(
    'checks the trimmed name after exactly one second and resets on typing',
    (tester) async {
      final checker = PendingNicknameChecker();
      final controller = NicknameAvailabilityController(checker: checker);
      controller.updateInput('  은혜  ');
      expect(controller.status, NicknameCheckStatus.waiting);
      expect(controller.canSave, isFalse);
      await tester.pump(const Duration(milliseconds: 999));
      expect(checker.names, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(checker.names, ['은혜']);
      expect(controller.status, NicknameCheckStatus.checking);
      checker.responses[0].complete(NicknameAvailability.available);
      await tester.pump();
      expect(controller.canSave, isTrue);
      expect(controller.checkedNickname, '은혜');

      controller.updateInput('평안');
      await tester.pump(const Duration(milliseconds: 600));
      controller.updateInput('평안이');
      await tester.pump(const Duration(milliseconds: 999));
      expect(checker.names, ['은혜']);
      await tester.pump(const Duration(milliseconds: 1));
      expect(checker.names, ['은혜', '평안이']);
      checker.responses[1].complete(NicknameAvailability.taken);
      await tester.pump();
      expect(controller.status, NicknameCheckStatus.taken);
      expect(controller.canSave, isFalse);
      controller.dispose();
    },
  );

  testWidgets(
    'invalid names and IME composition wait until valid committed input',
    (tester) async {
      final checker = PendingNicknameChecker();
      final controller = NicknameAvailabilityController(checker: checker);
      controller.updateInput('   ');
      await tester.pump(const Duration(seconds: 1));
      controller.updateInput('가');
      await tester.pump(const Duration(seconds: 1));
      controller.updateInput('가나', isComposing: true);
      await tester.pump(const Duration(seconds: 2));
      expect(checker.names, isEmpty);
      expect(controller.canSave, isFalse);

      controller.updateInput('가나', isComposing: false);
      await tester.pump(const Duration(milliseconds: 999));
      expect(checker.names, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(checker.names, ['가나']);
      checker.responses.single.complete(NicknameAvailability.available);
      await tester.pump();
      expect(controller.canSave, isTrue);
      controller.dispose();

      final editing = NicknameAvailabilityController(
        checker: checker,
        initialNickname: '은혜',
        editing: true,
      );
      editing.updateInput(' 은혜 ');
      await tester.pump(const Duration(seconds: 2));
      expect(editing.status, NicknameCheckStatus.unchanged);
      expect(editing.canSave, isTrue);
      expect(checker.names, ['가나']);
      editing.dispose();
    },
  );

  testWidgets(
    'stale successes and failures cannot replace the latest name or notify after dispose',
    (tester) async {
      final checker = PendingNicknameChecker();
      final controller = NicknameAvailabilityController(checker: checker);
      controller.updateInput('첫이름');
      await tester.pump(const Duration(seconds: 1));
      controller.updateInput('새이름');
      await tester.pump(const Duration(seconds: 1));
      checker.responses[0].complete(NicknameAvailability.taken);
      await tester.pump();
      expect(controller.status, NicknameCheckStatus.checking);
      checker.responses[1].complete(NicknameAvailability.available);
      await tester.pump();
      expect(controller.checkedNickname, '새이름');

      controller.updateInput('늦은실패');
      await tester.pump(const Duration(seconds: 1));
      controller.updateInput('현재이름');
      await tester.pump(const Duration(seconds: 1));
      checker.responses[3].complete(NicknameAvailability.available);
      await tester.pump();
      checker.responses[2].completeError(StateError('late test failure'));
      await tester.pump();
      expect(controller.status, NicknameCheckStatus.available);
      expect(controller.checkedNickname, '현재이름');
      expect(controller.canSave, isTrue);

      controller.updateInput('나중이름');
      await tester.pump(const Duration(seconds: 1));
      int notifications = 0;
      controller.addListener(() => notifications++);
      controller.dispose();
      checker.responses[4].complete(NicknameAvailability.available);
      await tester.pump();
      expect(notifications, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configured checks block button and keyboard submission until availability is confirmed',
    (tester) async {
      final checker = PendingNicknameChecker();
      final saves = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NicknamePage(
            availabilityChecker: checker,
            onSave: (name) async {
              saves.add(name);
              return savedSession(name);
            },
            onCompleted: (_) {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.enterText(input, '은혜');
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saves, isEmpty);

      await tester.pump(const Duration(seconds: 1));
      expect(checker.names, ['은혜']);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      // Done ends the previous input connection; a new attempt refocuses it.
      await tester.showKeyboard(input);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saves, isEmpty);
      checker.responses.single.complete(NicknameAvailability.available);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.showKeyboard(input);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saves, ['은혜']);
      await disposePage(tester);
    },
  );

  testWidgets(
    'taken names and failed checks stay blocked until a successful retry',
    (tester) async {
      final checker = PendingNicknameChecker();
      int saves = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: NicknamePage(
            availabilityChecker: checker,
            onSave: (name) async {
              saves++;
              return savedSession(name);
            },
            onCompleted: (_) {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.enterText(input, '이미사용');
      await tester.pump(const Duration(seconds: 1));
      checker.responses[0].complete(NicknameAvailability.taken);
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saves, 0);

      await tester.enterText(input, '새닉네임');
      await tester.pump(const Duration(seconds: 1));
      checker.responses[1].completeError(StateError('test offline'));
      await tester.pump();
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(saves, 0);
      final retry = find.byKey(const ValueKey('nickname-availability-retry'));
      await tester.ensureVisible(retry);
      await tester.pump();
      await tester.tap(retry);
      await tester.pump(const Duration(seconds: 1));
      expect(checker.names, ['이미사용', '새닉네임', '새닉네임']);
      checker.responses[2].complete(NicknameAvailability.available);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await disposePage(tester);
    },
  );

  testWidgets(
    'without a backend the existing save flow remains without claiming availability',
    (tester) async {
      final saves = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: NicknamePage(
            onSave: (name) async {
              saves.add(name);
              return savedSession(name);
            },
            onCompleted: (_) {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.enterText(input, '기쁨');
      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('사용할 수 있는 닉네임'), findsNothing);
      expect(find.text('중복 확인은 준비 중이에요. 현재 닉네임 저장은 가능해요.'), findsOneWidget);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(saves, ['기쁨']);
      await disposePage(tester);
    },
  );
  testWidgets('app gate passes its checker into required nickname onboarding', (
    tester,
  ) async {
    final repository = NicknameGateRepository();
    final checker = PendingNicknameChecker();
    await tester.pumpWidget(
      AmenMoaApp(
        sessionRepository: repository,
        nicknameAvailabilityChecker: checker,
        minimumSplashDuration: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nickname-screen')), findsOneWidget);
    await tester.enterText(input, '중복이름');
    await tester.pump(const Duration(seconds: 1));
    expect(checker.names, ['중복이름']);
    checker.responses.single.complete(NicknameAvailability.taken);
    await tester.pump();
    expect(find.text('이미 사용 중인 닉네임이에요.'), findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(repository.saveCalls, 0);
    await disposePage(tester);
  });
  testWidgets(
    'cursor events keep the deadline and a timed out check can retry',
    (tester) async {
      final checker = PendingNicknameChecker();
      final controller = NicknameAvailabilityController(checker: checker);
      controller.updateInput('하늘');
      await tester.pump(const Duration(milliseconds: 600));
      controller.updateInput('하늘', isComposing: false);
      await tester.pump(const Duration(milliseconds: 399));
      expect(checker.names, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      expect(checker.names, ['하늘']);

      await tester.pump(const Duration(milliseconds: 9999));
      expect(controller.status, NicknameCheckStatus.checking);
      await tester.pump(const Duration(milliseconds: 1));
      expect(controller.status, NicknameCheckStatus.error);
      expect(controller.canSave, isFalse);
      final retried = controller.retry();
      expect(checker.names, ['하늘', '하늘']);
      checker.responses[1].complete(NicknameAvailability.available);
      await tester.pump();
      await retried;
      expect(controller.status, NicknameCheckStatus.available);
      expect(controller.canSave, isTrue);
      controller.dispose();

      final unconfigured = NicknameAvailabilityController(
        checker: const UnconfiguredNicknameAvailabilityChecker(),
      );
      unconfigured.updateInput('가나', isComposing: true);
      await tester.pump(const Duration(seconds: 2));
      expect(unconfigured.canSave, isFalse);
      unconfigured.updateInput('가나', isComposing: false);
      expect(unconfigured.canSave, isTrue);
      unconfigured.dispose();
    },
  );
}
