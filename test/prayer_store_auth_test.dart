import 'package:amenmoa_front/features/experience/experience.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'each account restores only its own records and guest data stays separate',
    () async {
      SharedPreferences.setMockInitialValues({});
      final accountA = PrayerStore(userId: 'account-a');
      await accountA.load();
      await accountA.add(
        PrayerEntry('prayer-a', 'A의 기도', 120, DateTime.now(), 'A의 메모', '개인 기도'),
      );
      accountA.dispose();

      final accountB = PrayerStore(userId: 'account-b');
      await accountB.load();
      expect(accountB.entries, isEmpty);
      await accountB.add(
        PrayerEntry('prayer-b', 'B의 기도', 60, DateTime.now(), 'B의 메모', '개인 기도'),
      );
      accountB.dispose();

      final guest = PrayerStore();
      await guest.load();
      expect(guest.entries, isEmpty);
      await guest.add(
        PrayerEntry(
          'prayer-guest',
          '기기 저장 기도',
          180,
          DateTime.now(),
          '',
          '개인 기도',
        ),
      );
      guest.dispose();

      final returnedA = PrayerStore(userId: 'account-a');
      await returnedA.load();
      expect(returnedA.entries.single.id, 'prayer-a');
      expect(returnedA.entries.single.note, 'A의 메모');
      expect(returnedA.totalSeconds, 120);
      returnedA.dispose();

      final returnedB = PrayerStore(userId: 'account-b');
      await returnedB.load();
      expect(returnedB.entries.single.id, 'prayer-b');
      returnedB.dispose();

      final returnedGuest = PrayerStore();
      await returnedGuest.load();
      expect(returnedGuest.entries.single.id, 'prayer-guest');
      returnedGuest.dispose();
    },
  );
}
