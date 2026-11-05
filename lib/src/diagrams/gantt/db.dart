// Upstream: src/diagrams/gantt/db.ts

import '../../errors.dart';
import '../../util/url.dart';
import 'dates.dart';
import 'parser.dart';
import 'types.dart';

class GanttDbOptions {
  final void Function(String message)? warn;

  const GanttDbOptions({this.warn});
}

final RegExp _reNumericFormat = RegExp(r'^[YMDHhmsSZXx\-/.:, T]*$');
final RegExp _reTag = RegExp(r'^\s*(active|done|crit|milestone|vert)\s*$');
final RegExp _reAfter = RegExp(r'^after\s+([\d\w- ]+)');
final RegExp _reUntil = RegExp(r'^until\s+([\d\w- ]+)');
final RegExp _reDuration = RegExp(r'^(\d+(?:\.\d+)?)([Mdhmswy]|ms)$');
final RegExp _reTokenSplit = RegExp(r'[\s,]+');
final RegExp _reDigits = RegExp(r'^\d+$');
final RegExp _reIsoDateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _leadSpaceRe = RegExp(r'^\s+');
final RegExp _newlineSpaceRe = RegExp(r'\n\s+');
final Set<String> _dayNames = WEEKDAYS.map((day) => day.toLowerCase()).toSet();

// Scheduling walks tasks day by day and parses dates with a format the diagram supplies. This bounds the
// total, in rough character operations, so a hostile diagram fails instead of hanging.
const double _workLimit = 4e8;
const int _dayStep = 400;
const int _datedStep = 200;
const int _formatStep = 400;

// The one place the current time is read.
double clock([Object? now]) {
  if (now is DateTime) {
    return now.millisecondsSinceEpoch.toDouble();
  }
  if (now is num && now.isFinite) {
    return now.toDouble();
  }
  return DateTime.now().millisecondsSinceEpoch.toDouble();
}

(double, Unit) parseDuration(String str) {
  final statement = _reDuration.firstMatch(str.trim());
  return statement != null
      ? (double.parse(statement.group(1)!), statement.group(2)!)
      : (double.nan, 'ms');
}

List<String> _mergeTokens(List<String> existing, String txt) {
  final merged = <String>{...existing};
  for (final token in txt.toLowerCase().split(_reTokenSplit)) {
    if (token.isNotEmpty) merged.add(token);
  }
  return merged.toList();
}

DateTime? _parseJsFallbackDate(String str) {
  final trimmed = str.trim();
  if (trimmed.isEmpty) return null;
  if (_reIsoDateOnly.hasMatch(trimmed)) {
    try {
      final dt = DateTime.parse('${trimmed}T00:00:00Z').toLocal();
      return isValid(dt) ? dt : null;
    } catch (_) {
      return null;
    }
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return isValid(local) ? local : null;
  }
  // Handle slash dates like YYYY/MM/DD or MM/DD/YYYY that JS new Date(str) accepts.
  final slashIso = RegExp(r'^(\d{4})/(\d{1,2})/(\d{1,2})$').firstMatch(trimmed);
  if (slashIso != null) {
    return makeLocalDate(
      int.parse(slashIso.group(1)!),
      int.parse(slashIso.group(2)!) - 1,
      int.parse(slashIso.group(3)!),
    );
  }
  final slashUs = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(trimmed);
  if (slashUs != null) {
    return makeLocalDate(
      int.parse(slashUs.group(3)!),
      int.parse(slashUs.group(1)!) - 1,
      int.parse(slashUs.group(2)!),
    );
  }
  return null;
}

class GanttDb implements GanttModel, GanttBuilder {
  @override
  final String type = 'gantt';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  String dateFormat = '';
  @override
  String axisFormat = '';
  @override
  String? tickInterval;
  @override
  String todayMarker = '';
  @override
  List<String> includes = <String>[];
  @override
  List<String> excludes = <String>[];
  @override
  bool inclusiveEndDates = false;
  @override
  bool topAxis = false;
  @override
  String displayMode = '';
  @override
  String? weekday;
  @override
  String weekend = 'saturday';
  @override
  List<String> sections = <String>[];
  @override
  Map<String, String> links = <String, String>{};
  @override
  List<GanttTask> tasks = <GanttTask>[];

  final Map<String, GanttTask> _byId = <String, GanttTask>{};
  String _currentSection = '';
  int _taskCount = 0;
  int _lastOrder = 0;
  String? _lastTaskId;
  final GanttDbOptions _options;
  double _now = 0;
  double _work = 0;
  Set<String> _includeSet = <String>{};
  Set<String> _excludeSet = <String>{};
  List<bool> _excludedDays = <bool>[];
  bool _datedTokens = false;

  GanttDb([this._options = const GanttDbOptions()]);

  @override
  void setDateFormat(String txt) {
    dateFormat = txt;
  }

  @override
  void enableInclusiveEndDates() {
    inclusiveEndDates = true;
  }

  // Mermaid's grammar calls a method its database does not define, so `topAxis` crashes there.
  @override
  // ignore: non_constant_identifier_names
  void TopAxis() {
    topAxis = true;
  }

  @override
  void setAxisFormat(String txt) {
    axisFormat = txt;
  }

  @override
  void setTickInterval(String txt) {
    tickInterval = txt;
  }

  @override
  void setTodayMarker(String txt) {
    todayMarker = txt;
  }

  @override
  void setIncludes(String txt) {
    includes = _mergeTokens(includes, txt);
  }

  @override
  void setExcludes(String txt) {
    excludes = _mergeTokens(excludes, txt);
  }

  @override
  void setWeekday(String txt) {
    weekday = txt;
  }

  @override
  void setWeekend(String startDay) {
    weekend = startDay;
  }

  @override
  void setDiagramTitle(String txt) {
    title = txt;
  }

  @override
  void setAccTitle(String txt) {
    accTitle = txt.replaceFirst(_leadSpaceRe, '');
  }

  @override
  void setAccDescription(String txt) {
    accDescr = txt.replaceAll(_newlineSpaceRe, '\n');
  }

  @override
  void addSection(String txt) {
    _currentSection = txt;
    sections.add(txt);
  }

  @override
  void addTask(String descr, String dataStr) {
    final data = (dataStr.startsWith(':') ? dataStr.substring(1) : dataStr)
        .split(',');
    final task = GanttTask(
      id: '',
      task: descr,
      section: _currentSection,
      startTime: null,
      endTime: null,
      renderEndTime: null,
      manualEndTime: false,
      processed: false,
      active: false,
      done: false,
      crit: false,
      milestone: false,
      vert: false,
      order: -1,
      classes: <String>[],
      prevTaskId: _lastTaskId,
      raw: GanttTaskRaw(data: dataStr, start: null, end: ''),
    );

    RegExpMatch? tag;
    while (data.isNotEmpty && (tag = _reTag.firstMatch(data[0])) != null) {
      switch (tag!.group(1)) {
        case 'active':
          task.active = true;
          break;
        case 'done':
          task.done = true;
          break;
        case 'crit':
          task.crit = true;
          break;
        case 'milestone':
          task.milestone = true;
          break;
        case 'vert':
          task.vert = true;
          break;
      }
      data.removeAt(0);
    }
    // Mermaid fails with a TypeError on both of these.
    if (data.isEmpty) {
      throw PeleError(
        'Task "${descr.trim()}" needs a duration or an end date.',
        'semantic',
        const PeleErrorInfo(type: 'gantt'),
      );
    }
    if (data.length > 3) {
      throw PeleError(
        'Task "${descr.trim()}" has too many fields. A task takes an id, a start, and an end or duration.',
        'semantic',
        const PeleErrorInfo(type: 'gantt'),
      );
    }
    for (var i = 0; i < data.length; i++) {
      data[i] = data[i].trim();
    }

    if (data.length == 3) {
      task.id = data[0];
    } else {
      _taskCount++;
      task.id = 'task$_taskCount';
    }
    if (data.length > 1) task.raw.start = data[data.length - 2];
    task.raw.end = data[data.length - 1];

    if (!task.vert) task.order = _lastOrder++;
    tasks.add(task);
    _lastTaskId = task.id;
    _byId[task.id] = task;
  }

  @override
  void setLink(String ids, String link) {
    final href = safeUrl(link);
    for (final id in ids.split(',')) {
      if (_byId.containsKey(id)) links[id] = href;
    }
    setClass(ids, 'clickable');
  }

  // Callbacks are recognized and never run; the task is only marked clickable, as in Mermaid.
  @override
  void setClickEvent(String ids, String functionName, String? functionArgs) {
    setClass(ids, 'clickable');
  }

  void setClass(String ids, String className) {
    for (final id in ids.split(',')) {
      _byId[id]?.classes.add(className);
    }
  }

  // Resolves every task's start and end, from scratch on each call. A task may refer to tasks defined
  // after it, so, like Mermaid, this makes up to eleven passes, each of which schedules every task again.
  @override
  List<GanttTask> getTasks([Object? now]) {
    _now = clock(now);
    _work = 0;
    _includeSet = includes.toSet();
    _excludeSet = excludes.toSet();
    final weekendStart = weekend == 'friday'
        ? 5
        : weekend == 'saturday'
        ? 6
        : -1;
    final weekends = _excludeSet.contains('weekends');
    _excludedDays = List<bool>.generate(WEEKDAYS.length, (day) {
      final name = WEEKDAYS[day];
      final iso = day == 0 ? 7 : day;
      return (weekends &&
              weekendStart >= 0 &&
              (iso == weekendStart || iso == weekendStart + 1)) ||
          _excludeSet.contains(name.toLowerCase());
    });
    // A date written with only these tokens and separators can never read as a weekday name, so when
    // nothing else is excluded or included there is no need to format each day.
    _datedTokens =
        includes.isNotEmpty || !_reNumericFormat.hasMatch(dateFormat.trim());
    for (final token in excludes) {
      if (token != 'weekends' && !_dayNames.contains(token)) {
        _datedTokens = true;
      }
    }

    for (final task in tasks) {
      task.startTime = null;
      task.endTime = null;
      task.renderEndTime = null;
      task.processed = false;
      task.manualEndTime = false;
    }

    var allProcessed = _compileTasks();
    for (var i = 0; !allProcessed && i < 10; i++) {
      allProcessed = _compileTasks();
    }
    return tasks;
  }

  // Whether a day is excluded. A day matches a token by its weekday name, by its date as YYYY-MM-DD,
  // or by its date written in the chart's own format.
  bool isInvalidDate(DateTime date) {
    final weekdayExcluded = _excludedDays[date.weekday % 7];
    if (!_datedTokens) return weekdayExcluded;
    final template = dateFormat.trim();
    final dateOnly = isoDate(date);
    String? formatted = dateOnly;
    _spend(_datedStep);
    if (template != 'YYYY-MM-DD') {
      _spend(_formatStep + template.length * 8);
      formatted = format(date, template);
    }
    bool listed(Set<String> set) =>
        set.contains(dateOnly) ||
        (formatted != null && set.contains(formatted));
    if (listed(_includeSet)) return false;
    return weekdayExcluded || listed(_excludeSet);
  }

  void _spend(int units) {
    _work += units;
    if (_work > _workLimit) {
      throw PeleError(
        'The gantt chart takes too much work to schedule.',
        'limit',
        const PeleErrorInfo(type: 'gantt'),
      );
    }
  }

  DateTime? _parse(String str, String template) {
    _spend((template.length + 1) * (str.length + 1));
    return parseStrict(
      str,
      template,
      DateTime.fromMillisecondsSinceEpoch(_now.truncate()),
    );
  }

  DateTime _today() {
    final nowDt = DateTime.fromMillisecondsSinceEpoch(_now.truncate());
    return DateTime(nowDt.year, nowDt.month, nowDt.day);
  }

  void _warn(String Function() message) {
    final cb = _options.warn;
    if (cb != null) cb(message());
  }

  bool _compileTasks() {
    var allProcessed = true;
    for (final task in tasks) {
      _compileTask(task);
      allProcessed = allProcessed && task.processed;
    }
    return allProcessed;
  }

  void _compileTask(GanttTask task) {
    final start = task.raw.start;
    if (start == null) {
      // Mermaid fails with a TypeError when the first task has no start. It starts today here.
      final previous = task.prevTaskId == null ? null : _byId[task.prevTaskId!];
      task.startTime = previous != null ? previous.endTime : _today();
    } else {
      final startTime = _getStartDate(start);
      if (startTime != null) task.startTime = startTime;
    }
    if (task.startTime == null) return;
    task.endTime = _getEndDate(task.startTime!, task.raw.end);
    if (task.endTime == null) return;
    task.processed = true;
    task.manualEndTime = _parse(task.raw.end, 'YYYY-MM-DD') != null;
    _checkTaskDates(task);
  }

  List<GanttTask> _references(String keyword, String list) {
    final found = <GanttTask>[];
    List<String>? unknown;
    for (final id in list.split(' ')) {
      if (id.isEmpty) continue;
      final task = _byId[id];
      if (task != null) {
        found.add(task);
      } else {
        (unknown ??= <String>[]).add(id);
      }
    }
    if (unknown != null) {
      final ids = unknown;
      _warn(
        () =>
            'Gantt: "$keyword" refers to task ids that do not exist: ${ids.join(', ')}.',
      );
    }
    return found;
  }

  DateTime? _getStartDate(String raw) {
    final str = raw.trim();
    final template = dateFormat.trim();

    if ((template == 'x' || template == 'X') && _reDigits.hasMatch(str)) {
      return _checked(dateFromMs(double.tryParse(str) ?? double.nan), str);
    }

    final after = _reAfter.firstMatch(str);
    if (after != null) {
      final refTasks = _references('after', after.group(1)!);
      GanttTask? latest;
      for (final task in refTasks) {
        if (latest == null ||
            (task.endTime != null &&
                latest.endTime != null &&
                task.endTime!.millisecondsSinceEpoch >
                    latest.endTime!.millisecondsSinceEpoch)) {
          latest = task;
        }
      }
      return latest != null ? latest.endTime : _today();
    }

    final parsed = _parse(str, template);
    if (parsed != null) return parsed;

    // What does not fit the format gets a second chance with the JavaScript date parser, as in Mermaid.
    final date = _parseJsFallbackDate(str);
    if (!isValid(date) || date!.year < -10000 || date.year > 10000) {
      throw PeleError(
        'Invalid date:$str',
        'semantic',
        const PeleErrorInfo(type: 'gantt'),
      );
    }
    return date;
  }

  DateTime _checked(DateTime? date, String str) {
    if (!isValid(date)) {
      throw PeleError(
        'Invalid date:$str',
        'semantic',
        const PeleErrorInfo(type: 'gantt'),
      );
    }
    return date!;
  }

  DateTime? _getEndDate(DateTime startTime, String raw) {
    final str = raw.trim();

    final until = _reUntil.firstMatch(str);
    if (until != null) {
      final refTasks = _references('until', until.group(1)!);
      GanttTask? earliest;
      for (final task in refTasks) {
        if (earliest == null ||
            (task.startTime != null &&
                earliest.startTime != null &&
                task.startTime!.millisecondsSinceEpoch <
                    earliest.startTime!.millisecondsSinceEpoch)) {
          earliest = task;
        }
      }
      return earliest != null ? earliest.startTime : _today();
    }

    final template = dateFormat.trim();
    final parsed = _parse(str, template);
    if (parsed != null) {
      return inclusiveEndDates ? addDays(parsed, 1) : parsed;
    }

    final (value, unit) = parseDuration(str);
    if (value.isNaN) {
      _warn(
        () =>
            'Gantt: "$str" is neither a date in the "$template" format nor a duration such as "3d", so the task gets no duration.',
      );
      return startTime;
    }
    final end = add(startTime, value, unit);
    return isValid(end) ? end! : startTime;
  }

  // Pushes the end of a task out by one day for every excluded day it covers.
  void _checkTaskDates(GanttTask task) {
    if (excludes.isEmpty || task.manualEndTime) return;
    var cursor = addDays(task.startTime!, 1);
    var endTime = task.endTime!;
    final maxEndTime = addDays(endTime, 10000).millisecondsSinceEpoch;
    var invalid = false;
    DateTime? renderEndTime;
    while (cursor.millisecondsSinceEpoch <= endTime.millisecondsSinceEpoch) {
      _spend(_dayStep);
      if (!invalid) renderEndTime = endTime;
      invalid = isInvalidDate(cursor);
      if (invalid) {
        endTime = addDays(endTime, 1);
        if (endTime.millisecondsSinceEpoch > maxEndTime) {
          throw PeleError(
            'Failed to find a valid date that was not excluded by `excludes` after 10,000 iterations.',
            'semantic',
            const PeleErrorInfo(type: 'gantt'),
          );
        }
      }
      cursor = addDays(cursor, 1);
    }
    task.endTime = endTime;
    task.renderEndTime = renderEndTime;
  }
}
