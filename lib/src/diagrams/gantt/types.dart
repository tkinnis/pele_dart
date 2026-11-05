// Upstream: src/diagrams/gantt/types.ts

import '../../svg/root.dart';

class GanttTaskRaw {
  String data;
  String? start;
  String end;

  GanttTaskRaw({required this.data, this.start, required this.end});
}

class GanttTask {
  String id;
  // The task's label, under the name Mermaid gives it.
  String task;
  String section;
  // Unset until `getTasks` has scheduled the task, and still unset when what it refers to never resolves.
  DateTime? startTime;
  DateTime? endTime;
  // Where the bar ends when excluded days pushed the task's end out; null when the end was given as a date.
  DateTime? renderEndTime;
  bool manualEndTime;
  bool processed;
  bool active;
  bool done;
  bool crit;
  bool milestone;
  bool vert;
  // Row index in source order; -1 for vertical markers, which take no row.
  int order;
  List<String> classes;
  String? prevTaskId;
  GanttTaskRaw raw;

  GanttTask({
    required this.id,
    required this.task,
    required this.section,
    this.startTime,
    this.endTime,
    this.renderEndTime,
    required this.manualEndTime,
    required this.processed,
    required this.active,
    required this.done,
    required this.crit,
    required this.milestone,
    required this.vert,
    required this.order,
    required this.classes,
    this.prevTaskId,
    required this.raw,
  });
}

abstract interface class GanttModel implements RootModel {
  String get type;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
  String get dateFormat;
  String get axisFormat;
  String? get tickInterval;
  String get todayMarker;
  List<String> get includes;
  List<String> get excludes;
  bool get inclusiveEndDates;
  bool get topAxis;
  String get displayMode;
  // The day week-based ticks start on, when the chart names one. Mermaid's default is Sunday.
  String? get weekday;
  String get weekend;
  List<String> get sections;
  Map<String, String> get links;
  List<GanttTask> get tasks;
  // Schedules the tasks against the given time, or the current time, and returns them.
  List<GanttTask> getTasks([Object? now]);
}
