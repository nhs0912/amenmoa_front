import 'package:amenmoa_front/app/app_shell.dart';
import 'package:amenmoa_front/features/experience/experience.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('five storyboard tabs navigate on small and enlarged screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const MaterialApp(home: AppShell()));
    await tester.pumpAndSettle();
    expect(find.text('혼자 시작해도, 함께'), findsOneWidget);
    for (final pair in {
      '그룹': '내 그룹',
      '기도': '마음을 모으는 기도',
      '기록': '기도의 발자취',
      '프로필': '내 프로필',
    }.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(pair.key),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(pair.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  test(
    'records persist and duplicate session saves do not double count',
    () async {
      final store = PrayerStore();
      await store.load();
      final entry = PrayerEntry(
        'session-1',
        '감사',
        120,
        DateTime.now(),
        '평안',
        '개인 기도',
      );
      await store.add(entry);
      await store.add(entry);
      final restored = PrayerStore();
      await restored.load();
      expect(restored.entries.length, 1);
      expect(restored.todaySeconds, 120);
      expect(restored.entries.single.note, '평안');
      store.dispose();
      restored.dispose();
    },
  );
  testWidgets('timer pauses, resumes and saves elapsed time', (tester) async {
    final store = PrayerStore();
    await store.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openPage(
                context,
                TimerPage(store: store, title: '감사', kind: '개인 기도'),
              ),
              child: const Text('시작'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('시작'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('일시정지'));
    await tester.pump();
    expect(find.text('잠시 쉬는 중'), findsOneWidget);
    await tester.tap(find.text('기도 이어가기'));
    await tester.pump();
    expect(find.text('기도 중'), findsOneWidget);
    await tester.tap(find.text('기도 마치기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(store.entries.length, 1);
    expect(store.entries.single.title, '감사');
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
