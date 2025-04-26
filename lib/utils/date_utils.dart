class DateTimeUtils {
  static DateTime parseCreatedAt(dynamic value) {
    if (value == null) return DateTime.now();
    
    if (value is DateTime) return value;
    
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    
    if (value is String) {
      try {
        if (value.contains('T')) {
          return DateTime.parse(value);
        }
        return DateTime.fromMillisecondsSinceEpoch(int.parse(value));
      } catch (e) {
        print('Date parse error: $e for value: $value');
        return DateTime.now();
      }
    }
    
    return DateTime.now();
  }

  static String formatForDatabase(DateTime date) {
    return date.millisecondsSinceEpoch.toString();
  }

  static String formatForDisplay(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
