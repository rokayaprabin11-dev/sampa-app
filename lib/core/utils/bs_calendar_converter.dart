import 'package:nepali_utils/nepali_utils.dart';

class BSCalendarService {
  /// Convert AD date to BS
  static NepaliDateTime toBS(DateTime ad) =>
      ad.toNepaliDateTime();

  /// Convert BS date to AD
  static DateTime toAD(NepaliDateTime bs) =>
      bs.toDateTime();

  /// Get accurate month length for any BS year/month
  static int monthLength(int year, int month) =>
      NepaliDateTime(year, month).totalDays;

  /// Format BS date in Nepali numerals
  static String formatNe(NepaliDateTime dt) =>
      dt.format('yyyy MMMM dd', Language.nepali);

  /// Format BS date in Latin numerals
  static String formatEn(NepaliDateTime dt) =>
      dt.format('yyyy MMMM dd', Language.english);
}







