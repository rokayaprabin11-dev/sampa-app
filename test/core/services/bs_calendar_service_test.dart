import 'package:flutter_test/flutter_test.dart';
import 'package:nepali_utils/nepali_utils.dart';
import 'package:sampada/core/services/bs_calendar_service.dart';

void main() {
  group('BS Calendar — year boundary rollover', () {
    test('Chaitra 30 + 1 day = Baishakh 1', () {
      final chaitra30 = NepaliDateTime(2080, 12, 30);
      final next = chaitra30.add(const Duration(days: 1));
      expect(next.month, 1);
      expect(next.day, 1);
      expect(next.year, 2081);
    });

    test('AD ↔ BS roundtrip is lossless for 100 years', () {
      var date = DateTime(2000, 1, 1);
      for (int i = 0; i < 365 * 100; i++) {
        final bs = BSCalendarService.toBS(date);
        final back = BSCalendarService.toAD(bs);
        expect(back.year, equals(date.year),
            reason: 'Roundtrip failed for $date → $bs → $back');
        expect(back.month, equals(date.month));
        expect(back.day, equals(date.day));
        date = date.add(const Duration(days: 1));
      }
    });
  });
}
