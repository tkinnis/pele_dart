// Upstream: src/diagrams/gantt/dates.ts

// The parts of dayjs 1.11 that Mermaid's gantt code relies on, with the plugins it loads (custom parse format,
// advanced format, ISO week) and the English locale: strict parsing against a format, formatting, and calendar
// arithmetic, all in local time. Quirks are kept, because a date is accepted only when formatting the parsed
// result gives back the input.

import 'dart:math' as math;

import '../../util/math_js.dart';

const List<String> MONTHS = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const List<String> WEEKDAYS = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const int _day = 86400000;
const int _week = 7 * _day;
const int maxJsDateMs = 8640000000000000;

typedef Unit = String; // 'ms' | 's' | 'm' | 'h' | 'd' | 'w' | 'M' | 'y'

bool isValid(DateTime? date) {
  return date != null && date.millisecondsSinceEpoch.abs() <= maxJsDateMs;
}

DateTime? dateFromMs(num ms) {
  if (!ms.isFinite) return null;
  final t = ms.truncate();
  if (t.abs() > maxJsDateMs) return null;
  try {
    return DateTime.fromMillisecondsSinceEpoch(t);
  } catch (_) {
    return null;
  }
}

DateTime? makeLocalDate(
  int year, [
  int month0 = 0,
  int day = 1,
  int hours = 0,
  int minutes = 0,
  int seconds = 0,
  int ms = 0,
  bool adjustTwoDigitYear = true,
]) {
  final effYear = adjustTwoDigitYear && year >= 0 && year <= 99
      ? 1900 + year
      : year;
  try {
    final dt = DateTime(effYear, month0 + 1, day, hours, minutes, seconds, ms);
    return isValid(dt) ? dt : null;
  } catch (_) {
    return null;
  }
}

DateTime? makeUtcDateAsLocal(
  int year, [
  int month0 = 0,
  int day = 1,
  int hours = 0,
  int minutes = 0,
  int seconds = 0,
  int ms = 0,
]) {
  final effYear = year >= 0 && year <= 99 ? 1900 + year : year;
  try {
    final dt = DateTime.utc(
      effYear,
      month0 + 1,
      day,
      hours,
      minutes,
      seconds,
      ms,
    ).toLocal();
    return isValid(dt) ? dt : null;
  } catch (_) {
    return null;
  }
}

String _pad(int value, int length) {
  final s = '$value';
  return s.length >= length ? s : '${'0' * (length - s.length)}$s';
}

String _ordinal(int n) {
  const s = <String>['th', 'st', 'nd', 'rd'];
  final v = n % 100;
  final idx1 = v >= 20 ? (v - 20) % 10 : -1;
  final suffix = (idx1 >= 0 && idx1 < s.length)
      ? s[idx1]
      : (v >= 0 && v < s.length ? s[v] : s[0]);
  return '$n$suffix';
}

int _utcOffset(DateTime date) {
  final tzOffset = -date.timeZoneOffset.inMinutes;
  final offset = -roundJs(tzOffset / 15) * 15;
  return offset == 0 ? 0 : offset;
}

String _zone(DateTime date) {
  final offset = _utcOffset(date);
  final minutes = offset.abs();
  return '${offset >= 0 ? '+' : '-'}${_pad(minutes ~/ 60, 2)}:${_pad(minutes % 60, 2)}';
}

DateTime _wallUtc(DateTime date) {
  if (date.isUtc) return date;
  return DateTime.fromMillisecondsSinceEpoch(
    date.millisecondsSinceEpoch + date.timeZoneOffset.inMilliseconds,
    isUtc: true,
  );
}

int isoWeekday(DateTime date) {
  return date.weekday;
}

DateTime addDays(DateTime date, int days) {
  if (days == 0) return date;
  final nextMs = date.millisecondsSinceEpoch + days * _day;
  if (nextMs.abs() <= maxJsDateMs) {
    final tz = date.timeZoneOffset;
    final candidate = DateTime.fromMillisecondsSinceEpoch(nextMs);
    if (candidate.timeZoneOffset == tz) return candidate;
  }
  final w = _wallUtc(date);
  return DateTime(
    w.year,
    w.month,
    w.day + days,
    w.hour,
    w.minute,
    w.second,
    w.millisecond,
  );
}

DateTime? _tryAddDays(DateTime date, int days) {
  if (days == 0) return isValid(date) ? date : null;
  final nextMs = date.millisecondsSinceEpoch + days * _day;
  if (nextMs.abs() <= maxJsDateMs) {
    final tz = date.timeZoneOffset;
    final candidate = DateTime.fromMillisecondsSinceEpoch(nextMs);
    if (candidate.timeZoneOffset == tz) return candidate;
  }
  final w = _wallUtc(date);
  return makeLocalDate(
    w.year,
    w.month - 1,
    w.day + days,
    w.hour,
    w.minute,
    w.second,
    w.millisecond,
    false,
  );
}

// Sets the month or the year, keeping the day of the month unless the new month is shorter.
DateTime? _setCalendar(
  DateTime date,
  DateTime? Function(DateTime firstWall) apply,
) {
  final w = _wallUtc(date);
  final first = makeLocalDate(
    w.year,
    w.month - 1,
    1,
    w.hour,
    w.minute,
    w.second,
    w.millisecond,
    false,
  );
  if (first == null) return null;
  final shifted = apply(w);
  if (shifted == null) return null;
  final sw = _wallUtc(shifted);
  final last = DateTime(sw.year, sw.month + 1, 0, 23, 59, 59, 999);
  return makeLocalDate(
    sw.year,
    sw.month - 1,
    math.min(w.day, _wallUtc(last).day),
    sw.hour,
    sw.minute,
    sw.second,
    sw.millisecond,
    false,
  );
}

DateTime? add(DateTime date, double amount, Unit unit) {
  if (!amount.isFinite) return null;
  switch (unit) {
    case 'M':
      final m = roundJs(amount);
      return _setCalendar(
        date,
        (w) => makeLocalDate(
          w.year,
          (w.month - 1) + m,
          1,
          w.hour,
          w.minute,
          w.second,
          w.millisecond,
          false,
        ),
      );
    case 'y':
      final y = roundJs(amount);
      return _setCalendar(
        date,
        (w) => makeLocalDate(
          w.year + y,
          w.month - 1,
          1,
          w.hour,
          w.minute,
          w.second,
          w.millisecond,
          false,
        ),
      );
    case 'd':
      if (amount.abs() > 200000000) return null;
      return _tryAddDays(date, roundJs(amount));
    case 'w':
      if (amount.abs() > 30000000) return null;
      return _tryAddDays(date, roundJs(7 * amount));
    case 'h':
      return dateFromMs(date.millisecondsSinceEpoch + amount * 3600000);
    case 'm':
      return dateFromMs(date.millisecondsSinceEpoch + amount * 60000);
    case 's':
      return dateFromMs(date.millisecondsSinceEpoch + amount * 1000);
    default:
      return dateFromMs(date.millisecondsSinceEpoch + amount);
  }
}

DateTime _weekThursday(DateTime date) {
  return addDays(date, 4 - isoWeekday(date));
}

int _isoWeek(DateTime date) {
  final thursday = _weekThursday(date);
  final jan1 = DateTime(thursday.year, 1, 1);
  final weekday = isoWeekday(jan1);
  final first = addDays(jan1, 4 - weekday + (weekday > 4 ? 7 : 0));
  final zoneDelta = (_utcOffset(first) - _utcOffset(thursday)) * 60000;
  final weeks =
      (thursday.millisecondsSinceEpoch -
          first.millisecondsSinceEpoch -
          zoneDelta) /
      _week;
  return (weeks < 0 ? weeks.ceil() : weeks.floor()) + 1;
}

final RegExp _reAdvanced = RegExp(
  r'\[([^\]]+)]|Q|wo|ww|w|WW|W|zzz|z|gggg|GGGG|Do|X|x|k{1,2}|S',
);
final RegExp _reFormat = RegExp(
  r'\[([^\]]+)]|YYYY|YY|M{1,4}|D{1,2}|d{1,4}|H{1,2}|h{1,2}|a|A|m{1,2}|s{1,2}|Z{1,2}|SSS',
);
const String _defaultFormat = 'YYYY-MM-DDTHH:mm:ssZ';

// Returns null for the week-of-year and time zone name tokens, which need dayjs plugins Mermaid
// does not load and so fail there.
String? format(DateTime? date, String template) {
  if (!isValid(date)) return 'Invalid Date';
  final d = date!;
  final str = template.isNotEmpty ? template : _defaultFormat;
  if (str == 'YYYY-MM-DD') return isoDate(d);
  if (str == 'X') return '${(d.millisecondsSinceEpoch / 1000).floor()}';
  if (str == 'x') return '${d.millisecondsSinceEpoch}';
  final w = _wallUtc(d);
  if (str == 'YYYY') return _pad(w.year, 4);
  var unsupported = false;
  final advanced = str.replaceAllMapped(_reAdvanced, (m) {
    final match = m.group(0)!;
    switch (match) {
      case 'Q':
        return '${((w.month) / 3).ceil()}';
      case 'Do':
        return '[${_ordinal(w.day)}]';
      case 'GGGG':
        return '${_wallUtc(_weekThursday(d)).year}';
      case 'W':
        return '${_isoWeek(d)}';
      case 'WW':
        return _pad(_isoWeek(d), 2);
      case 'k':
        return '${w.hour == 0 ? 24 : w.hour}';
      case 'kk':
        return _pad(w.hour == 0 ? 24 : w.hour, 2);
      case 'X':
        return '${(d.millisecondsSinceEpoch / 1000).floor()}';
      case 'x':
        return '${d.millisecondsSinceEpoch}';
      case 'gggg':
      case 'wo':
      case 'w':
      case 'ww':
      case 'z':
      case 'zzz':
        unsupported = true;
        return match;
      default:
        return match;
    }
  });
  if (unsupported) return null;
  final hours = w.hour;
  final dow = w.weekday % 7;
  return advanced.replaceAllMapped(_reFormat, (m) {
    final literal = m.group(1);
    if (literal != null && literal.isNotEmpty) return literal;
    final match = m.group(0)!;
    switch (match) {
      case 'YY':
        return sliceJs('${w.year}', -2);
      case 'YYYY':
        return _pad(w.year, 4);
      case 'M':
        return '${w.month}';
      case 'MM':
        return _pad(w.month, 2);
      case 'MMM':
        return MONTHS[w.month - 1].substring(0, 3);
      case 'MMMM':
        return MONTHS[w.month - 1];
      case 'D':
        return '${w.day}';
      case 'DD':
        return _pad(w.day, 2);
      case 'd':
        return '$dow';
      case 'dd':
        return WEEKDAYS[dow].substring(0, 2);
      case 'ddd':
        return WEEKDAYS[dow].substring(0, 3);
      case 'dddd':
        return WEEKDAYS[dow];
      case 'H':
        return '$hours';
      case 'HH':
        return _pad(hours, 2);
      case 'h':
        return '${hours % 12 == 0 ? 12 : hours % 12}';
      case 'hh':
        return _pad(hours % 12 == 0 ? 12 : hours % 12, 2);
      case 'a':
        return hours < 12 ? 'am' : 'pm';
      case 'A':
        return hours < 12 ? 'AM' : 'PM';
      case 'm':
        return '${w.minute}';
      case 'mm':
        return _pad(w.minute, 2);
      case 's':
        return '${w.second}';
      case 'ss':
        return _pad(w.second, 2);
      case 'SSS':
        return _pad(w.millisecond, 3);
      case 'Z':
        return _zone(d);
      default:
        return _zone(d).replaceFirst(':', '');
    }
  });
}

String isoDate(DateTime date) {
  final w = _wallUtc(date);
  final year = w.year;
  final month = w.month;
  final day = w.day;
  final yStr = (year >= 1000 && year <= 9999) ? '$year' : _pad(year, 4);
  return '$yStr${month < 10 ? '-0' : '-'}$month${day < 10 ? '-0' : '-'}$day';
}

class _Fields {
  int? year;
  int? month;
  int? day;
  bool dayGiven = false;
  int? hours;
  int? minutes;
  int? seconds;
  int? milliseconds;
  int? week;
  int? offset;
  bool? afternoon;
}

typedef _FieldReader = bool Function(_Fields fields, String input);

class _RegexStep {
  final RegExp re;
  final _FieldReader read;

  const _RegexStep({required this.re, required this.read});
}

final RegExp _reTokens = RegExp(
  r'(\[[^[]*\])|([-_:/.,()\s]+)|(A|a|Q|YYYY|YY?|ww?|MM?M?M?|Do|DD?|hh?|HH?|mm?|ss?|S{1,3}|z|ZZ?)',
);
final RegExp _reLiteral = RegExp(r'\[[^\]]+]');
final RegExp _match1 = RegExp(r'\d');
final RegExp _match2 = RegExp(r'\d\d');
final RegExp _match3 = RegExp(r'\d{3}');
final RegExp _match4 = RegExp(r'\d{4}');
final RegExp _match1To2 = RegExp(r'\d\d?');
final RegExp _matchSigned = RegExp(r'[+-]?\d+');
final RegExp _matchOffset = RegExp(r'[+-]\d\d:?(\d\d)?|Z');
final RegExp _matchWord = RegExp(r'\d*[^-_:/,()\s\d]+');
final RegExp _reOffsetParts = RegExp(r'([+-]|\d\d)');
final RegExp _reDigits = RegExp(r'\d+');
final RegExp _reLocalized = RegExp(r'[Ll]');
final RegExp _reStripBrackets = RegExp(r'^\[|\]$');

bool _readOffset(_Fields fields, String input) {
  if (input == 'Z') {
    fields.offset = 0;
    return true;
  }
  final parts = _reOffsetParts
      .allMatches(input)
      .map((m) => m.group(0)!)
      .toList();
  final p1 = int.tryParse(parts[1]) ?? 0;
  final p2 = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
  final minutes = p1 * 60 + p2;
  fields.offset = minutes == 0 ? 0 : (parts[0] == '+' ? -minutes : minutes);
  return true;
}

_FieldReader _monthName(List<String> names) {
  return (_Fields fields, String input) {
    final index = names.indexOf(input) + 1;
    if (index < 1) return false;
    fields.month = index % 12 == 0 ? index : index % 12;
    return true;
  };
}

final Map<String, _RegexStep> _readers = <String, _RegexStep>{
  'A': _RegexStep(
    re: _matchWord,
    read: (f, input) {
      f.afternoon = input == 'PM';
      return true;
    },
  ),
  'a': _RegexStep(
    re: _matchWord,
    read: (f, input) {
      f.afternoon = input == 'pm';
      return true;
    },
  ),
  'Q': _RegexStep(
    re: _match1,
    read: (f, input) {
      f.month = (int.parse(input) - 1) * 3 + 1;
      return true;
    },
  ),
  'S': _RegexStep(
    re: _match1,
    read: (f, input) {
      f.milliseconds = int.parse(input) * 100;
      return true;
    },
  ),
  'SS': _RegexStep(
    re: _match2,
    read: (f, input) {
      f.milliseconds = int.parse(input) * 10;
      return true;
    },
  ),
  'SSS': _RegexStep(
    re: _match3,
    read: (f, input) {
      f.milliseconds = int.parse(input);
      return true;
    },
  ),
  's': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.seconds = int.parse(input);
      return true;
    },
  ),
  'ss': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.seconds = int.parse(input);
      return true;
    },
  ),
  'm': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.minutes = int.parse(input);
      return true;
    },
  ),
  'mm': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.minutes = int.parse(input);
      return true;
    },
  ),
  'H': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.hours = int.parse(input);
      return true;
    },
  ),
  'h': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.hours = int.parse(input);
      return true;
    },
  ),
  'HH': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.hours = int.parse(input);
      return true;
    },
  ),
  'hh': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.hours = int.parse(input);
      return true;
    },
  ),
  'D': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.day = int.parse(input);
      return true;
    },
  ),
  'DD': _RegexStep(
    re: _match2,
    read: (f, input) {
      f.day = int.parse(input);
      return true;
    },
  ),
  'Do': _RegexStep(
    re: _matchWord,
    read: (f, input) {
      final digits = _reDigits.firstMatch(input);
      if (digits == null) return false;
      // dayjs keeps the digits as a string here, so even "0" counts as a day having been given.
      f.day = int.tryParse(digits.group(0)!) ?? 0;
      f.dayGiven = true;
      for (var i = 1; i <= 31; i++) {
        if (_ordinal(i) == input) f.day = i;
      }
      return true;
    },
  ),
  'w': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.week = int.parse(input);
      return true;
    },
  ),
  'ww': _RegexStep(
    re: _match2,
    read: (f, input) {
      f.week = int.parse(input);
      return true;
    },
  ),
  'M': _RegexStep(
    re: _match1To2,
    read: (f, input) {
      f.month = int.parse(input);
      return true;
    },
  ),
  'MM': _RegexStep(
    re: _match2,
    read: (f, input) {
      f.month = int.parse(input);
      return true;
    },
  ),
  'MMM': _RegexStep(
    re: _matchWord,
    read: _monthName(MONTHS.map((m) => m.substring(0, 3)).toList()),
  ),
  'MMMM': _RegexStep(re: _matchWord, read: _monthName(MONTHS)),
  'Y': _RegexStep(
    re: _matchSigned,
    read: (f, input) {
      f.year = int.tryParse(input);
      return f.year != null;
    },
  ),
  'YY': _RegexStep(
    re: _match2,
    read: (f, input) {
      final n = int.parse(input);
      f.year = n + (n > 68 ? 1900 : 2000);
      return true;
    },
  ),
  'YYYY': _RegexStep(
    re: _match4,
    read: (f, input) {
      f.year = int.parse(input);
      return true;
    },
  ),
  'Z': _RegexStep(re: _matchOffset, read: _readOffset),
  'ZZ': _RegexStep(re: _matchOffset, read: _readOffset),
};

final Map<String, List<Object>?> _compiledCache = <String, List<Object>?>{};

List<Object>? _compile(String template) {
  if (_compiledCache.containsKey(template)) return _compiledCache[template];
  if (_compiledCache.length >= 64) _compiledCache.clear();
  // dayjs expands localized tokens through a locale table the English locale does not have, and fails.
  if (_reLocalized.hasMatch(template.replaceAll(_reLiteral, ''))) {
    return _compiledCache[template] = null;
  }
  final matches = _reTokens.allMatches(template).toList();
  if (matches.isEmpty) return _compiledCache[template] = null;
  final steps = matches.map<Object>((m) {
    final token = m.group(0)!;
    return _readers[token] ?? token.replaceAll(_reStripBrackets, '');
  }).toList();
  return _compiledCache[template] = steps;
}

double _jsNumber(String s) {
  final t = s.trim();
  if (t.isEmpty) return 0;
  return double.tryParse(t) ?? double.nan;
}

DateTime? _loose(String input, String template, DateTime now) {
  if (template == 'x' || template == 'X') {
    return dateFromMs((template == 'X' ? 1000 : 1) * _jsNumber(input));
  }
  final steps = _compile(template);
  if (steps == null) return null;
  final f = _Fields();
  var rest = input;
  var start = 0;
  for (final step in steps) {
    if (step is String) {
      start += step.length;
      continue;
    }
    final regexStep = step as _RegexStep;
    final match = regexStep.re.firstMatch(sliceJs(rest, start));
    if (match == null || !regexStep.read(f, match.group(0)!)) return null;
    // dayjs drops the first occurrence of the matched text, wherever it is, and does not move `start`.
    rest = rest.replaceFirst(match.group(0)!, '');
  }
  if (f.afternoon != null && f.hours != null) {
    if (f.afternoon!) {
      if (f.hours! < 12) f.hours = f.hours! + 12;
    } else if (f.hours == 12) {
      f.hours = 0;
    }
  }
  final hasYear = f.year != null && f.year != 0;
  final hasMonth = f.month != null && f.month != 0;
  final hasDay = f.dayGiven || (f.day != null && f.day != 0);
  final day = hasDay ? f.day! : (!hasYear && !hasMonth ? now.day : 1);
  final year = hasYear ? f.year! : now.year;
  var month0 = 0;
  if (!(hasYear && !hasMonth)) {
    month0 = (f.month != null && f.month! > 0) ? f.month! - 1 : (now.month - 1);
  }
  final hours = f.hours ?? 0;
  final minutes = f.minutes ?? 0;
  final seconds = f.seconds ?? 0;
  final ms = f.milliseconds ?? 0;
  if (f.offset != null) {
    return makeUtcDateAsLocal(
      year,
      month0,
      day,
      hours,
      minutes,
      seconds,
      ms + f.offset! * 60000,
    );
  }
  // Applying a week number needs a dayjs plugin Mermaid does not load.
  if (f.week != null && f.week != 0) return null;
  return makeLocalDate(year, month0, day, hours, minutes, seconds, ms);
}

int _parse2Digits(String s, int offset) {
  final d0 = s.codeUnitAt(offset) - 0x30;
  final d1 = s.codeUnitAt(offset + 1) - 0x30;
  if (d0 < 0 || d0 > 9 || d1 < 0 || d1 > 9) return -1;
  return d0 * 10 + d1;
}

int _parse4Digits(String s, int offset) {
  final hi = _parse2Digits(s, offset);
  final lo = _parse2Digits(s, offset + 2);
  if (hi < 0 || lo < 0) return -1;
  return hi * 100 + lo;
}

int _maxDaysInMonth(int y, int m) {
  if (m == 2) {
    return (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) ? 29 : 28;
  }
  return (m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31;
}

// Parses the way `dayjs(input, format, true)` does. `now` supplies the fields the format leaves out.
DateTime? parseStrict(String input, String template, DateTime now) {
  if (template == 'YYYY-MM-DD') {
    if (input.length != 10 ||
        input.codeUnitAt(4) != 0x2d ||
        input.codeUnitAt(7) != 0x2d) {
      return null;
    }
    final y = _parse4Digits(input, 0);
    final m = _parse2Digits(input, 5);
    final d = _parse2Digits(input, 8);
    if (y >= 100 && m >= 1 && m <= 12 && d >= 1 && d <= _maxDaysInMonth(y, m)) {
      return DateTime(y, m, d);
    }
    if (y > 0 && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
      final dt = makeLocalDate(y, m - 1, d);
      return (dt != null && dt.year == y && dt.month == m && dt.day == d)
          ? dt
          : null;
    }
  } else if (template == 'YYYY') {
    if (input.length != 4) return null;
    final y = _parse4Digits(input, 0);
    if (y >= 100) return DateTime(y, 1, 1);
    if (y > 0) return makeLocalDate(y, 0, 1);
    return null;
  }
  final date = _loose(input, template, now);
  return date != null && isValid(date) && format(date, template) == input
      ? date
      : null;
}
