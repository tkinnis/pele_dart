// Upstream: src/diagrams/sequence/types.ts

import '../../svg/root.dart';

/// The message kinds, numbered as in Mermaid.
abstract final class LINETYPE {
  static const int SOLID = 0;
  static const int DOTTED = 1;
  static const int NOTE = 2;
  static const int SOLID_CROSS = 3;
  static const int DOTTED_CROSS = 4;
  static const int SOLID_OPEN = 5;
  static const int DOTTED_OPEN = 6;
  static const int LOOP_START = 10;
  static const int LOOP_END = 11;
  static const int ALT_START = 12;
  static const int ALT_ELSE = 13;
  static const int ALT_END = 14;
  static const int OPT_START = 15;
  static const int OPT_END = 16;
  static const int ACTIVE_START = 17;
  static const int ACTIVE_END = 18;
  static const int PAR_START = 19;
  static const int PAR_AND = 20;
  static const int PAR_END = 21;
  static const int RECT_START = 22;
  static const int RECT_END = 23;
  static const int SOLID_POINT = 24;
  static const int DOTTED_POINT = 25;
  static const int AUTONUMBER = 26;
  static const int CRITICAL_START = 27;
  static const int CRITICAL_OPTION = 28;
  static const int CRITICAL_END = 29;
  static const int BREAK_START = 30;
  static const int BREAK_END = 31;
  static const int PAR_OVER_START = 32;
  static const int BIDIRECTIONAL_SOLID = 33;
  static const int BIDIRECTIONAL_DOTTED = 34;
  static const int SOLID_TOP = 41;
  static const int SOLID_BOTTOM = 42;
  static const int STICK_TOP = 43;
  static const int STICK_BOTTOM = 44;
  static const int SOLID_ARROW_TOP_REVERSE = 45;
  static const int SOLID_ARROW_BOTTOM_REVERSE = 46;
  static const int STICK_ARROW_TOP_REVERSE = 47;
  static const int STICK_ARROW_BOTTOM_REVERSE = 48;
  static const int SOLID_TOP_DOTTED = 51;
  static const int SOLID_BOTTOM_DOTTED = 52;
  static const int STICK_TOP_DOTTED = 53;
  static const int STICK_BOTTOM_DOTTED = 54;
  static const int SOLID_ARROW_TOP_REVERSE_DOTTED = 55;
  static const int SOLID_ARROW_BOTTOM_REVERSE_DOTTED = 56;
  static const int STICK_ARROW_TOP_REVERSE_DOTTED = 57;
  static const int STICK_ARROW_BOTTOM_REVERSE_DOTTED = 58;
  static const int CENTRAL_CONNECTION = 59;
  static const int CENTRAL_CONNECTION_REVERSE = 60;
  static const int CENTRAL_CONNECTION_DUAL = 61;
}

abstract final class PLACEMENT {
  static const int LEFTOF = 0;
  static const int RIGHTOF = 1;
  static const int OVER = 2;
}

class SeqText {
  const SeqText({required this.text, this.wrap, this.type});

  final String text;
  final bool? wrap;
  final String? type;
}

class SeqBoxData {
  const SeqBoxData({
    required this.text,
    required this.color,
    required this.wrap,
  });

  final String? text;
  final String color;
  final bool? wrap;
}

class SeqBox {
  SeqBox({
    required this.name,
    required this.wrap,
    required this.fill,
    List<String>? actorKeys,
  }) : actorKeys = actorKeys ?? <String>[];

  final String? name;
  final bool wrap;
  final String fill;
  final List<String> actorKeys;
}

class SeqActor {
  SeqActor({
    required this.box,
    required this.name,
    required this.description,
    required this.wrap,
    required this.prevActor,
    this.nextActor,
    Map<String, Object?>? links,
    Map<String, Object?>? properties,
    this.details,
    required this.type,
  }) : links = links ?? <String, Object?>{},
       properties = properties ?? <String, Object?>{};

  SeqBox? box;
  final String name;
  final String description;
  final bool wrap;
  final String? prevActor;
  String? nextActor;
  final Map<String, Object?> links;
  final Map<String, Object?> properties;

  /// The id of the page element named by a `details` statement. Pele has no page to read it from.
  String? details;
  final String type;
}

class SeqNumbering {
  const SeqNumbering({
    required this.start,
    required this.step,
    required this.visible,
  });

  final double? start;
  final double? step;
  final bool visible;
}

class SeqMessage {
  const SeqMessage({
    required this.id,
    required this.from,
    required this.to,
    required this.message,
    required this.wrap,
    this.type,
    this.activate,
    this.placement,
    this.centralConnection,
    this.answer,
  });

  final String id;
  final String? from;
  final String? to;

  /// Either a [String] or a [SeqNumbering].
  final Object message;
  final bool wrap;
  final int? type;
  final bool? activate;
  final int? placement;
  final int? centralConnection;
  final Object? answer;
}

class SeqNote {
  const SeqNote({
    required this.actor,
    required this.placement,
    required this.message,
    required this.wrap,
  });

  /// Either a [String] or a [List<String>].
  final Object actor;
  final int placement;
  final String message;
  final bool wrap;
}

/// One entry of the statement list the parser hands to `apply`, as Mermaid's grammar builds it.
class SeqStatement {
  SeqStatement({
    required this.type,
    this.actor,
    this.draw,
    this.description,
    this.config,
    this.signalType,
    this.from,
    this.to,
    this.msg,
    this.activate,
    this.centralConnection,
    this.placement,
    this.text,
    this.boxData,
    this.boxText,
    this.loopText,
    this.optText,
    this.altText,
    this.parText,
    this.criticalText,
    this.optionText,
    this.breakText,
    this.color,
    this.sequenceIndex,
    this.sequenceIndexStep,
    this.sequenceVisible,
  });

  String type;

  /// Either a [String] or a [List<String>].
  Object? actor;
  String? draw;
  SeqText? description;
  String? config;
  int? signalType;
  String? from;
  String? to;
  SeqText? msg;
  bool? activate;
  int? centralConnection;
  int? placement;
  SeqText? text;
  SeqBoxData? boxData;
  String? boxText;

  /// Either a [SeqText] or a [String].
  Object? loopText;
  SeqText? optText;
  SeqText? altText;
  SeqText? parText;
  SeqText? criticalText;
  SeqText? optionText;
  SeqText? breakText;
  SeqText? color;
  double? sequenceIndex;
  double? sequenceIndexStep;
  bool? sequenceVisible;
}

/// Either a [SeqStatement], a [String], or a [List<SeqItem>].
typedef SeqItem = Object;

abstract interface class SequenceModel implements RootModel {
  String get type;
  Map<String, SeqActor> get actors;
  Map<String, int> get createdActors;
  Map<String, int> get destroyedActors;
  List<SeqBox> get boxes;
  List<SeqMessage> get messages;
  List<SeqNote> get notes;
  String? get title;
  @override
  String? get accTitle;
  @override
  String? get accDescr;
}
