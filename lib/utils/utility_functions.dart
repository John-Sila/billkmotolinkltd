import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  // Cached formatter (good)
  static final DateFormat standardAppDate =
      DateFormat('EEE dd MMM yyyy, HH:mm');

  // Returns current time as HH:mm:ss
  static String getCurrentTimeString() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:"
           "${now.minute.toString().padLeft(2, '0')}:"
           "${now.second.toString().padLeft(2, '0')}";
  }

  // returns a string of now in the format "Friday_5th_December"
  static String formattedFileDate([DateTime? date]) {
    final now = date ?? DateTime.now();

    return "${now.weekdayName()}_${now.day}${now.daySuffix()}_${now.monthName()}";
  }

  // Formats any DateTime using the standard format --- not just now
  static String formatStandard(DateTime date) {
    return standardAppDate.format(date);
  }

}

extension AppDateTimeExtensions on DateTime {
  static const _weekdays = [
    '', // padding for 1-based index
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];

  static const _months = [
    '', // padding
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  String weekdayName() => _weekdays[weekday];

  String monthName() => _months[month];

  String daySuffix() {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }
}