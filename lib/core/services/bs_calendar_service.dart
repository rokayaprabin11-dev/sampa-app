import 'package:nepali_utils/nepali_utils.dart';

class BSCalendarService {
  BSCalendarService._();

  static NepaliDateTime toBS(DateTime adDate) => adDate.toNepaliDateTime();

  static DateTime toAD(NepaliDateTime bsDate) => bsDate.toDateTime();
}
