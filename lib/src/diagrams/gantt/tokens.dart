// Upstream: src/diagrams/gantt/tokens.ts

abstract final class T {
  static const int END = 0;
  static const int ERROR = 1;
  static const int open_directive = 2;
  static const int acc_title = 3;
  static const int acc_title_value = 4;
  static const int acc_descr = 5;
  static const int acc_descr_value = 6;
  static const int acc_descr_multiline_value = 7;
  static const int NL = 8;
  static const int href = 9;
  static const int callbackname = 10;
  static const int callbackargs = 11;
  static const int click = 12;
  static const int gantt = 13;
  static const int dateFormat = 14;
  static const int inclusiveEndDates = 15;
  static const int topAxis = 16;
  static const int axisFormat = 17;
  static const int tickInterval = 18;
  static const int includes = 19;
  static const int excludes = 20;
  static const int todayMarker = 21;
  static const int weekday_monday = 22;
  static const int weekday_tuesday = 23;
  static const int weekday_wednesday = 24;
  static const int weekday_thursday = 25;
  static const int weekday_friday = 26;
  static const int weekday_saturday = 27;
  static const int weekday_sunday = 28;
  static const int weekend_friday = 29;
  static const int weekend_saturday = 30;
  static const int date = 31;
  static const int title = 32;
  static const int accDescription = 33;
  static const int section = 34;
  static const int taskTxt = 35;
  static const int taskData = 36;
  static const int COLON = 37;
  static const int EOF = 38;
}

const List<String> TOKEN_NAMES = <String>[
  r'$end',
  'INVALID',
  'open_directive',
  'acc_title',
  'acc_title_value',
  'acc_descr',
  'acc_descr_value',
  'acc_descr_multiline_value',
  'NL',
  'href',
  'callbackname',
  'callbackargs',
  'click',
  'gantt',
  'dateFormat',
  'inclusiveEndDates',
  'topAxis',
  'axisFormat',
  'tickInterval',
  'includes',
  'excludes',
  'todayMarker',
  'weekday_monday',
  'weekday_tuesday',
  'weekday_wednesday',
  'weekday_thursday',
  'weekday_friday',
  'weekday_saturday',
  'weekday_sunday',
  'weekend_friday',
  'weekend_saturday',
  'date',
  'title',
  'accDescription',
  'section',
  'taskTxt',
  'taskData',
  ':',
  'EOF',
];
