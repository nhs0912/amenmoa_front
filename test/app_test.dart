import 'package:amenmoa_front/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts on home and navigates between all four tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const AmenMoaApp());
    await tester.pumpAndSettle();

    expect(find.text('오늘도 함께 기도해요'), findsOneWidget);

    for (final destination in {
      '모임': '함께 기도할 모임',
      '기도제목': '마음을 나눌 기도제목',
      '프로필': '평안한 하루 보내세요',
      '홈': '오늘도 함께 기도해요',
    }.entries) {
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(destination.key),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(destination.value), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  for (final size in [const Size(360, 640), const Size(1024, 768)]) {
    testWidgets('handles $size with enlarged text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(const AmenMoaApp());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('모임'));
      await tester.pumpAndSettle();
      expect(find.text('함께 기도할 모임'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
