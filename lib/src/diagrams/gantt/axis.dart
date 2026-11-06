// Upstream: src/diagrams/gantt/axis.ts

// Time axis support, following d3-time and d3-time-format (English locale, local time), which Mermaid uses:
// the `axisFormat` specifiers, tick intervals with d3's `every` rule, and its choice of automatic ticks.

import 'dart:math' as math;

import 'dates.dart';

const int _second = 1000;
const int _minute = 60 * _second;
const int _hour = 60 * _minute;
const int _day = 24 * _hour;
const int _week = 7 * _day;
const int _month = 30 * _day;
const int _year = 365 * _day;

typedef TickUnit = String; // 'millisecond' | 'second' | 'minute' | 'hour' | 'day' | 'week' | 'month' | 'year'

class _MDate {
  DateTime? _dt;
  DateTime? _wall;
  int _tzMin = 0;

  _MDate(num ms) {
    setTime(ms);
  }

  _MDate.fromDateTime(DateTime dt) {
    _assign(isValid(dt) ? dt : null);
  }

  void _assign(DateTime? dt) {
    _dt = dt;
    _wall = null;
  }

  DateTime get _w {
    var w = _wall;
    if (w == null) {
      final dt = _dt!;
      if (dt.isUtc) {
        w = dt;
        _tzMin = 0;
      } else {
        final offset = dt.timeZoneOffset;
        _tzMin = -offset.inMinutes;
        w = DateTime.fromMillisecondsSinceEpoch(
          dt.millisecondsSinceEpoch + offset.inMilliseconds,
          isUtc: true,
        );
      }
      _wall = w;
    }
    return w;
  }

  bool get isFinite => _dt != null;
  double get ms => _dt?.millisecondsSinceEpoch.toDouble() ?? double.nan;

  void setTime(num ms) {
    _assign(dateFromMs(ms));
  }

  int getMilliseconds() {
    final rem = _dt!.millisecondsSinceEpoch % 1000;
    return rem < 0 ? rem + 1000 : rem;
  }

  int getSeconds() => _w.second;
  int getUTCSeconds() {
    final sec = (_dt!.millisecondsSinceEpoch / 1000).floor() % 60;
    return sec < 0 ? sec + 60 : sec;
  }

  int getMinutes() => _w.minute;
  int getHours() => _w.hour;
  int getDate() => _w.day;
  int getDay() => _w.weekday % 7;
  int getMonth() => _w.month - 1;
  int getFullYear() => _w.year;
  int getTimezoneOffset() {
    _w;
    return _tzMin;
  }

  void setHours(int h, [int m = 0, int s = 0, int ms = 0]) {
    if (_dt == null) return;
    final w = _w;
    if (w.hour == h && w.minute == m && w.second == s && w.millisecond == ms) {
      return;
    }
    _assign(makeLocalDate(w.year, w.month - 1, w.day, h, m, s, ms, false));
  }

  void setDate(int day) {
    if (_dt == null) return;
    final w = _w;
    final curDay = w.day;
    if (day == curDay) return;
    _assign(addDays(_dt!, day - curDay));
  }

  void setMonth(int month0, [int? day]) {
    if (_dt == null) return;
    final w = _w;
    _assign(
      makeLocalDate(
        w.year,
        month0,
        day ?? w.day,
        w.hour,
        w.minute,
        w.second,
        w.millisecond,
        false,
      ),
    );
  }

  void setFullYear(int year) {
    if (_dt == null) return;
    final w = _w;
    _assign(
      makeLocalDate(
        year,
        w.month - 1,
        w.day,
        w.hour,
        w.minute,
        w.second,
        w.millisecond,
        false,
      ),
    );
  }
}

class _Calendar {
  final void Function(_MDate d) floor;
  final void Function(_MDate d, int step) offset;
  // The value d3 tests against a step: a tick falls where it is a multiple of the step.
  final int Function(_MDate d)? field;
  // How many values `field` cycles through, which bounds how far apart filtered ticks can be.
  final double cycle;
  final int ms;

  const _Calendar({
    required this.floor,
    required this.offset,
    this.field,
    required this.cycle,
    required this.ms,
  });
}

void _startOfDay(_MDate d) {
  d.setHours(0, 0, 0, 0);
}

_Calendar _weekCalendar(int weekStart) {
  return _Calendar(
    floor: (d) {
      if (!d.isFinite) return;
      d.setDate(d.getDate() - ((d.getDay() + 7 - weekStart) % 7));
      _startOfDay(d);
    },
    offset: (d, step) {
      if (!d.isFinite) return;
      d.setDate(d.getDate() + step * 7);
    },
    cycle: double.infinity,
    ms: _week,
  );
}

final Map<String, _Calendar> _calendars = <String, _Calendar>{
  'millisecond': _Calendar(
    floor: (_) {},
    offset: (d, step) => d.setTime(d.ms + step),
    cycle: double.infinity,
    ms: 1,
  ),
  'second': _Calendar(
    floor: (d) {
      if (!d.isFinite) return;
      d.setTime(d.ms - d.getMilliseconds());
    },
    offset: (d, step) => d.setTime(d.ms + step * _second),
    field: (d) => d.getUTCSeconds(),
    cycle: 60,
    ms: _second,
  ),
  'minute': _Calendar(
    floor: (d) {
      if (!d.isFinite) return;
      d.setTime(d.ms - d.getMilliseconds() - d.getSeconds() * _second);
    },
    offset: (d, step) => d.setTime(d.ms + step * _minute),
    field: (d) => d.getMinutes(),
    cycle: 60,
    ms: _minute,
  ),
  'hour': _Calendar(
    floor: (d) {
      if (!d.isFinite) return;
      d.setTime(
        d.ms -
            d.getMilliseconds() -
            d.getSeconds() * _second -
            d.getMinutes() * _minute,
      );
    },
    offset: (d, step) => d.setTime(d.ms + step * _hour),
    field: (d) => d.getHours(),
    cycle: 24,
    ms: _hour,
  ),
  'day': _Calendar(
    floor: _startOfDay,
    offset: (d, step) {
      if (!d.isFinite) return;
      d.setDate(d.getDate() + step);
    },
    field: (d) => d.getDate() - 1,
    cycle: 31,
    ms: _day,
  ),
  'month': _Calendar(
    floor: (d) {
      if (!d.isFinite) return;
      d.setDate(1);
      _startOfDay(d);
    },
    offset: (d, step) {
      if (!d.isFinite) return;
      d.setMonth(d.getMonth() + step);
    },
    field: (d) => d.getMonth(),
    cycle: 12,
    ms: _month,
  ),
  'year': _Calendar(
    floor: (d) {
      if (!d.isFinite) return;
      d.setMonth(0, 1);
      _startOfDay(d);
    },
    offset: (d, step) {
      if (!d.isFinite) return;
      d.setFullYear(d.getFullYear() + step);
    },
    cycle: double.infinity,
    ms: _year,
  ),
};

// Whole units between two floored dates, discounting a change of UTC offset between them.
int _span(_MDate start, _MDate end, int unit) {
  return ((end.ms -
              start.ms -
              (end.getTimezoneOffset() - start.getTimezoneOffset()) * _minute) /
          unit)
      .floor();
}

int _mod(int a, int b) {
  return ((a % b) + b) % b;
}

// The interval d3's `unit.every(step)` gives.
_Calendar _every(TickUnit unit, int step, int weekStart) {
  final base = unit == 'week' ? _weekCalendar(weekStart) : _calendars[unit]!;
  if (step <= 1) return base;
  if (unit == 'millisecond') {
    return _Calendar(
      floor: (d) {
        if (!d.isFinite) return;
        d.setTime((d.ms / step).floor() * step);
      },
      offset: (d, n) => d.setTime(d.ms + n * step),
      field: base.field,
      cycle: base.cycle,
      ms: base.ms,
    );
  }
  if (unit == 'year') {
    return _Calendar(
      floor: (d) {
        if (!d.isFinite) return;
        d.setFullYear((d.getFullYear() / step).floor() * step);
        base.floor(d);
      },
      offset: (d, n) {
        if (!d.isFinite) return;
        d.setFullYear(d.getFullYear() + n * step);
      },
      field: base.field,
      cycle: base.cycle,
      ms: base.ms,
    );
  }
  if (unit == 'week') {
    final epoch = _MDate(0);
    base.floor(epoch);
    return _Calendar(
      floor: (d) {
        base.floor(d);
        if (!d.isFinite) return;
        base.offset(d, -_mod(_span(epoch, d, _week), step));
      },
      offset: (d, n) => base.offset(d, n * step),
      field: base.field,
      cycle: base.cycle,
      ms: base.ms,
    );
  }
  final field = base.field!;
  bool test(_MDate d) => field(d) % step == 0;
  return _Calendar(
    floor: (d) {
      // Date overflow makes field(d) NaN, which can never match the interval.
      for (base.floor(d); d.isFinite && !test(d); base.floor(d)) {
        d.setTime(d.ms - 1);
      }
    },
    offset: (d, n) {
      for (var i = 0; i < n && d.isFinite; i++) {
        do {
          base.offset(d, 1);
        } while (d.isFinite && !test(d));
      }
    },
    field: base.field,
    cycle: base.cycle,
    ms: base.ms,
  );
}

// Ticks from start to stop inclusive, or null when there would be more than `limit`.
List<double>? _range(_Calendar calendar, double start, double stop, int limit) {
  final d = _MDate(start - 1);
  calendar.floor(d);
  calendar.offset(d, 1);
  calendar.floor(d);
  final out = <double>[];
  var previous = double.negativeInfinity;
  while (d.isFinite && d.ms <= stop && d.ms > previous) {
    if (out.length >= limit) return null;
    previous = d.ms;
    out.add(previous);
    calendar.offset(d, 1);
    calendar.floor(d);
  }
  return out;
}

double _tickStep(double start, double stop, int count) {
  final step = (stop - start) / math.max(0, count);
  final power = (math.log(step) / math.ln10).floor();
  final error = step / math.pow(10, power);
  final factor = error >= math.sqrt(50)
      ? 10
      : error >= math.sqrt(10)
      ? 5
      : error >= math.sqrt2
      ? 2
      : 1;
  return math.pow(10, power).toDouble() * factor;
}

const List<(TickUnit, int, int)> _auto = <(TickUnit, int, int)>[
  ('second', 1, _second),
  ('second', 5, 5 * _second),
  ('second', 15, 15 * _second),
  ('second', 30, 30 * _second),
  ('minute', 1, _minute),
  ('minute', 5, 5 * _minute),
  ('minute', 15, 15 * _minute),
  ('minute', 30, 30 * _minute),
  ('hour', 1, _hour),
  ('hour', 3, 3 * _hour),
  ('hour', 6, 6 * _hour),
  ('hour', 12, 12 * _hour),
  ('day', 1, _day),
  ('day', 2, 2 * _day),
  ('week', 1, _week),
  ('month', 1, _month),
  ('month', 3, 3 * _month),
  ('year', 1, _year),
];

// About `count` ticks at round times, chosen the way d3's time scale chooses them.
List<double> autoTicks(double start, double stop, int count) {
  final target = (stop - start) / count;
  var i = 0;
  while (i < _auto.length && _auto[i].$3 <= target) {
    i++;
  }
  _Calendar calendar;
  if (i == _auto.length) {
    final step = math.max<double>(
      1,
      _tickStep(start / _year, stop / _year, count),
    );
    calendar = _every('year', step.isFinite ? step.round() : 1, 0);
  } else if (i == 0) {
    final step = math.max<double>(_tickStep(start, stop, count), 1);
    calendar = _every('millisecond', step.isFinite ? step.round() : 1, 0);
  } else {
    final (unit, step, _) =
        _auto[target / _auto[i - 1].$3 < _auto[i].$3 / target ? i - 1 : i];
    calendar = _every(unit, step, 0);
  }
  return _range(calendar, start, stop, 4 * count + 8) ?? <double>[];
}

final RegExp _reInterval = RegExp(
  r'^([1-9]\d*)(millisecond|second|minute|hour|day|week|month)$',
);
const List<String> _weekStarts = <String>[
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

// Ticks for a `tickInterval` such as `1week`, or null when it is not one or asks for more than `limit`.
List<double>? intervalTicks(
  String interval,
  String weekday,
  double start,
  double stop,
  int limit,
) {
  final m = _reInterval.firstMatch(interval);
  if (m == null) return null;
  final step = int.parse(m.group(1)!);
  final unit = m.group(2)!;
  final calendar = _every(
    unit,
    step,
    math.max(0, _weekStarts.indexOf(weekday)),
  );
  if ((stop - start) /
          (math.min<double>(step.toDouble(), calendar.cycle) * calendar.ms) >
      limit) {
    return null;
  }
  return _range(calendar, start, stop, limit);
}

String _pad(int value, String fill, int width) {
  final sign = value < 0 ? '-' : '';
  final digits = '${sign.isNotEmpty ? -value : value}';
  return '$sign${digits.length < width ? '${fill * (width - digits.length)}$digits' : digits}';
}

_MDate _floored(_MDate date, _Calendar calendar) {
  final d = _MDate(date.ms);
  calendar.floor(d);
  return d;
}

// Weeks since the last `weekStart` day before the year began, which is d3's %U and %W.
int _weekOfYear(_MDate date, int weekStart) {
  final week = _weekCalendar(weekStart);
  final yearStart = _floored(date, _calendars['year']!);
  return _span(
    _floored(_MDate(yearStart.ms - 1), week),
    _floored(date, week),
    _week,
  );
}

// The Thursday that decides which ISO week and ISO year a date belongs to.
_MDate _isoThursday(_MDate date) {
  final thursday = _weekCalendar(4);
  final day = date.getDay();
  final d = _floored(
    (day >= 4 || day == 0) ? date : _MDate(date.ms - 1),
    thursday,
  );
  if (!(day >= 4 || day == 0)) {
    thursday.offset(d, 1);
    thursday.floor(d);
  }
  return d;
}

const Map<String, String> _pads = <String, String>{'-': '', '_': ' ', '0': '0'};

// Formats a date with a d3 time format specifier such as `%Y-%m-%d`.
String timeFormat(String specifier, DateTime date) {
  if (specifier == '%Y-%m-%d') return isoDate(date);
  if (specifier == '%s') {
    return '${(date.millisecondsSinceEpoch / 1000).floor()}';
  }
  final md = _MDate.fromDateTime(date);
  final out = StringBuffer();
  var from = 0;
  final n = specifier.length;
  for (var i = 0; i < n; i++) {
    if (specifier.codeUnitAt(i) != 37) continue;
    out.write(specifier.substring(from, i));
    i++;
    var c = i < n ? specifier[i] : '';
    var fill = _pads[c];
    if (fill != null) {
      i++;
      c = i < n ? specifier[i] : '';
    } else {
      fill = c == 'e' ? ' ' : '0';
    }
    out.write(_directive(c, md, fill));
    from = i + 1;
  }
  if (from < n) {
    out.write(specifier.substring(from));
  }
  return out.toString();
}

String _directive(String c, _MDate d, String p) {
  switch (c) {
    case 'a':
      return WEEKDAYS[d.getDay()].substring(0, 3);
    case 'A':
      return WEEKDAYS[d.getDay()];
    case 'b':
      return MONTHS[d.getMonth()].substring(0, 3);
    case 'B':
      return MONTHS[d.getMonth()];
    case 'c':
      return timeFormat('%x, %X', d._dt!);
    case 'd':
    case 'e':
      return _pad(d.getDate(), p, 2);
    case 'f':
      return '${_pad(d.getMilliseconds(), p, 3)}000';
    case 'g':
      return _pad(_isoThursday(d).getFullYear() % 100, p, 2);
    case 'G':
      return _pad(_isoThursday(d).getFullYear() % 10000, p, 4);
    case 'H':
      return _pad(d.getHours(), p, 2);
    case 'I':
      final h12 = d.getHours() % 12;
      return _pad(h12 == 0 ? 12 : h12, p, 2);
    case 'j':
      return _pad(
        1 +
            _span(
              _floored(d, _calendars['year']!),
              _floored(d, _calendars['day']!),
              _day,
            ),
        p,
        3,
      );
    case 'L':
      return _pad(d.getMilliseconds(), p, 3);
    case 'm':
      return _pad(d.getMonth() + 1, p, 2);
    case 'M':
      return _pad(d.getMinutes(), p, 2);
    case 'p':
      return d.getHours() >= 12 ? 'PM' : 'AM';
    case 'q':
      return '${1 + (d.getMonth() ~/ 3)}';
    case 'Q':
      return '${d.ms.truncate()}';
    case 's':
      return '${(d.ms / 1000).floor()}';
    case 'S':
      return _pad(d.getSeconds(), p, 2);
    case 'u':
      final dow = d.getDay();
      return '${dow == 0 ? 7 : dow}';
    case 'U':
      return _pad(_weekOfYear(d, 0), p, 2);
    case 'V':
      final thursday = _isoThursday(d);
      final yearStart = _floored(thursday, _calendars['year']!);
      final first = _floored(yearStart, _weekCalendar(4));
      return _pad(
        _span(first, thursday, _week) + (yearStart.getDay() == 4 ? 1 : 0),
        p,
        2,
      );
    case 'w':
      return '${d.getDay()}';
    case 'W':
      return _pad(_weekOfYear(d, 1), p, 2);
    case 'x':
      return timeFormat('%-m/%-d/%Y', d._dt!);
    case 'X':
      return timeFormat('%-I:%M:%S %p', d._dt!);
    case 'y':
      return _pad(d.getFullYear() % 100, p, 2);
    case 'Y':
      return _pad(d.getFullYear() % 10000, p, 4);
    case 'Z':
      final z = d.getTimezoneOffset();
      final abs = z.abs();
      return '${z > 0 ? '-' : '+'}${_pad(abs ~/ 60, '0', 2)}${_pad(abs % 60, '0', 2)}';
    case '%':
      return '%';
    default:
      return c;
  }
}
