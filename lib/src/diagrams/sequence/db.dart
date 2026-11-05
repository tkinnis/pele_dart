// Upstream: src/diagrams/sequence/db.ts

import 'dart:convert';

import '../../errors.dart';
import '../../util/math_js.dart';
import '../../util/yaml.dart';
import 'colors.dart';
import 'parser.dart';
import 'types.dart';

class SeqDbOptions {
  const SeqDbOptions({this.wrap, this.sequenceWrap});

  /// The top-level `wrap` setting, which the `%%{wrap}%%` directive also sets.
  final bool? wrap;

  /// `sequence.wrap`.
  final bool? sequenceWrap;
}

final RegExp _reWrap = RegExp(r'^:?wrap:');
final RegExp _reNowrap = RegExp(r'^:?nowrap:');
final RegExp _reWrapPrefix = RegExp(r'^:?(?:no)?wrap:');
final RegExp _reBoxFunction = RegExp(r'^(?:rgba?|hsla?)\s*\(');
final RegExp _reLineTerminator = RegExp('[\r\u2028\u2029]');
final RegExp _reWord = RegExp(r'^\w*');
final RegExp _reLeadSpaces = RegExp(r'^\s+');
final RegExp _reNewlineSpaces = RegExp(r'\n\s+');

Never _fail(String message) {
  throw PeleError(message, 'semantic', const PeleErrorInfo(type: 'sequence'));
}

SeqText _extractWrap(String raw) {
  final text = raw.trim();
  final wrap = _reWrap.hasMatch(text)
      ? true
      : (_reNowrap.hasMatch(text) ? false : null);
  return SeqText(
    text: (wrap == null ? text : text.replaceFirst(_reWrapPrefix, '')).trim(),
    wrap: wrap,
  );
}

// Splits a box line into a leading color and the rest, as Mermaid's
// /^((?:rgba?|hsla?)\s*\(.*\)|\w*)(.*)$/ does. `.` stops at a line terminator, so a line that
// holds one outside the gap before the parenthesis does not match at all.
(String, String)? _splitBox(String str) {
  final fn = _reBoxFunction.firstMatch(str);
  if (fn != null) {
    final fn0 = fn.group(0)!;
    final close = str.lastIndexOf(')');
    if (close >= fn0.length) {
      if (_reLineTerminator.hasMatch(str.substring(fn0.length))) return null;
      return (str.substring(0, close + 1), str.substring(close + 1));
    }
  }
  if (_reLineTerminator.hasMatch(str)) return null;
  final word = _reWord.firstMatch(str)!.group(0)!;
  return (word, str.substring(word.length));
}

List<(String, Object?)> _entries(Object? value) {
  if (value is String) {
    final chars = codePointsOf(value);
    return <(String, Object?)>[
      for (var i = 0; i < chars.length; i++) ('$i', chars[i]),
    ];
  }
  if (value is Map) {
    return <(String, Object?)>[
      for (final entry in value.entries) ('${entry.key}', entry.value),
    ];
  }
  if (value is List) {
    return <(String, Object?)>[
      for (var i = 0; i < value.length; i++) ('$i', value[i]),
    ];
  }
  return const <(String, Object?)>[];
}

bool _isTruthy(Object? v) =>
    v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);

class SeqDb implements SequenceModel, SeqBuilder {
  SeqDb([SeqDbOptions options = const SeqDbOptions()])
    : _wrapEnabled = options.wrap,
      _sequenceWrap = options.sequenceWrap ?? false;

  @override
  final String type = 'sequence';
  @override
  final Map<String, SeqActor> actors = <String, SeqActor>{};
  @override
  final Map<String, int> createdActors = <String, int>{};
  @override
  final Map<String, int> destroyedActors = <String, int>{};
  @override
  final List<SeqBox> boxes = <SeqBox>[];
  @override
  final List<SeqMessage> messages = <SeqMessage>[];
  @override
  final List<SeqNote> notes = <SeqNote>[];
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;

  String? _prevActor;
  SeqBox? _currentBox;
  String? _lastCreated;
  String? _lastDestroyed;
  final bool? _wrapEnabled;
  final bool _sequenceWrap;
  final Map<String, int> _active = <String, int>{};

  bool autoWrap() {
    return _wrapEnabled ?? _sequenceWrap;
  }

  @override
  void setAccTitle(String text) {
    accTitle = text.replaceFirst(_reLeadSpaces, '');
  }

  @override
  void setAccDescription(String text) {
    accDescr = text.replaceAll(_reNewlineSpaces, '\n');
  }

  @override
  void setDiagramTitle(String text) {
    title = text;
  }

  @override
  SeqText parseMessage(String str) {
    return _extractWrap(str);
  }

  @override
  SeqBoxData parseBoxData(String str) {
    final match = _splitBox(str);
    var color = (match != null && match.$1.isNotEmpty)
        ? match.$1.trim()
        : 'transparent';
    var boxTitle = (match != null && match.$2.isNotEmpty)
        ? match.$2.trim()
        : null;
    if (!isCssColor(color)) {
      color = 'transparent';
      boxTitle = str.trim();
    }
    if (boxTitle == null) {
      return SeqBoxData(text: null, color: color, wrap: null);
    }
    final extracted = _extractWrap(boxTitle);
    return SeqBoxData(
      text: extracted.text.isNotEmpty ? extracted.text : null,
      color: color,
      wrap: extracted.wrap,
    );
  }

  void addBox(SeqBoxData data) {
    final box = SeqBox(
      name: data.text,
      wrap: data.wrap ?? autoWrap(),
      fill: data.color,
      actorKeys: <String>[],
    );
    _currentBox = box;
    boxes.add(box);
  }

  void addActor(
    String id,
    String name,
    SeqText? description,
    String? actorType, [
    String? metadata,
  ]) {
    var assignedBox = _currentBox;
    Map<String, YamlValue>? doc;
    if (metadata != null) {
      YamlValue parsed;
      try {
        parsed = parseYaml(
          metadata.contains('\n') ? '$metadata\n' : '{\n$metadata\n}',
        );
      } catch (error) {
        final msg = error is StateError ? error.message : '$error';
        throw PeleError(
          'Config of participant "$id" is not valid YAML. $msg',
          'syntax',
          const PeleErrorInfo(type: 'sequence'),
        );
      }
      if (parsed is Map<String, YamlValue>) {
        doc = parsed;
      } else if (parsed is Map) {
        doc = <String, YamlValue>{
          for (final entry in parsed.entries) '${entry.key}': entry.value,
        };
      }
    }
    final docType = (doc != null && doc.containsKey('type'))
        ? doc['type']
        : null;
    final docAlias = (doc != null && doc.containsKey('alias'))
        ? doc['alias']
        : null;
    if (docType != null) actorType = '$docType';
    if (_isTruthy(docAlias) &&
        (description == null || description.text == name)) {
      description = SeqText(
        text: '$docAlias',
        wrap: description?.wrap,
        type: actorType,
      );
    }

    final old = actors[id];
    if (old != null) {
      if (_currentBox != null && old.box != null && _currentBox != old.box) {
        _fail(
          "A same participant should only be defined in one Box: ${old.name} can't be in '${old.box!.name ?? 'undefined'}' and in '${_currentBox!.name ?? 'undefined'}' at the same time.",
        );
      }
      assignedBox = old.box ?? _currentBox;
      old.box = assignedBox;
      if (name == old.name && description == null) return;
    }
    // A participant that is only mentioned in a message has no kind and takes its name as its label.
    if (description == null || actorType == null) {
      description = SeqText(text: name, type: actorType);
    }

    actors[id] = SeqActor(
      box: assignedBox,
      name: name,
      description: description.text,
      wrap: description.wrap ?? autoWrap(),
      prevActor: _prevActor,
      links: <String, Object?>{},
      properties: <String, Object?>{},
      type: actorType ?? 'participant',
    );
    if (_prevActor != null) {
      final prev = actors[_prevActor!];
      if (prev != null) prev.nextActor = id;
    }
    if (_currentBox != null) _currentBox!.actorKeys.add(id);
    _prevActor = id;
  }

  void addMessage(String from, String to, SeqText message, Object? answer) {
    messages.add(
      SeqMessage(
        id: '${messages.length}',
        from: from,
        to: to,
        message: message.text,
        wrap: message.wrap ?? autoWrap(),
        answer: answer,
      ),
    );
  }

  bool addSignal([
    String? from,
    String? to,
    SeqText? message,
    int? signalType,
    bool activate = false,
    int? centralConnection,
  ]) {
    // Mermaid recounts every earlier message here. A running count per participant says the same.
    if (signalType == LINETYPE.ACTIVE_END) {
      final count = (from != null && from.isNotEmpty)
          ? (_active[from] ?? 0)
          : 0;
      if (count < 1) {
        _fail('Trying to inactivate an inactive participant ($from)');
      }
      _active[from!] = count - 1;
    } else if (signalType == LINETYPE.ACTIVE_START &&
        from != null &&
        from.isNotEmpty) {
      _active[from] = (_active[from] ?? 0) + 1;
    }
    messages.add(
      SeqMessage(
        id: '${messages.length}',
        from: from,
        to: to,
        message: message?.text ?? '',
        wrap: message?.wrap ?? autoWrap(),
        type: signalType,
        activate: activate,
        centralConnection: centralConnection ?? 0,
      ),
    );
    return true;
  }

  void addNote(Object actor, int placement, SeqText message) {
    final wrap = message.wrap ?? autoWrap();
    final note = SeqNote(
      actor: actor,
      placement: placement,
      message: message.text,
      wrap: wrap,
    );
    final pair = actor is String
        ? <String>[actor, actor]
        : (actor as List<String>);
    notes.add(note);
    messages.add(
      SeqMessage(
        id: '${messages.length}',
        from: pair[0],
        to: pair[1],
        message: message.text,
        wrap: wrap,
        type: LINETYPE.NOTE,
        placement: placement,
      ),
    );
  }

  // Mermaid logs and ignores menu text that is not valid JSON. It also undoes the `&amp;` and
  // `&equals;` its sanitizer writes; Pele has no sanitizer, and a `;` cannot occur in the text.
  void addLinks(String actorId, SeqText text) {
    final actor = actors[actorId];
    if (actor == null) return;
    try {
      final parsed = jsonDecode(text.text);
      for (final (key, value) in _entries(parsed)) {
        actor.links[key] = value;
      }
    } catch (_) {
      return;
    }
  }

  void addALink(String actorId, SeqText text) {
    final actor = actors[actorId];
    if (actor == null) return;
    final sep = text.text.indexOf('@');
    actor.links[sliceJs(text.text, 0, sep - 1).trim()] = sliceJs(
      text.text,
      sep + 1,
    ).trim();
  }

  void addProperties(String actorId, SeqText text) {
    final actor = actors[actorId];
    if (actor == null) return;
    try {
      final parsed = jsonDecode(text.text);
      for (final (key, value) in _entries(parsed)) {
        actor.properties[key] = value;
      }
    } catch (_) {
      return;
    }
  }

  // Mermaid reads the properties and links from a page element with this id. Pele keeps the id.
  void addDetails(String actorId, SeqText text) {
    final actor = actors[actorId];
    if (actor != null) actor.details = text.text;
  }

  // Mermaid walks the nested statement lists by recursion; an explicit stack takes any depth.
  @override
  void apply(SeqItem root) {
    final lists = <List<SeqItem>>[];
    final at = <int>[];
    SeqItem? item = root;
    while (true) {
      if (item != null) {
        if (item is List<SeqItem>) {
          lists.add(item);
          at.add(0);
        } else if (item is SeqStatement) {
          _applyOne(item);
        }
      }
      final depth = lists.length - 1;
      if (depth < 0) return;
      final list = lists[depth];
      if (at[depth] < list.length) {
        item = list[at[depth]++];
      } else {
        lists.removeLast();
        at.removeLast();
        item = null;
      }
    }
  }

  void _applyOne(SeqStatement param) {
    final actor = param.actor is String ? param.actor as String : null;
    switch (param.type) {
      case 'sequenceIndex':
        messages.add(
          SeqMessage(
            id: '${messages.length}',
            from: null,
            to: null,
            message: SeqNumbering(
              start: param.sequenceIndex,
              step: param.sequenceIndexStep,
              visible: param.sequenceVisible == true,
            ),
            wrap: false,
            type: param.signalType,
          ),
        );
        break;
      case 'addParticipant':
        addActor(actor!, actor, param.description, param.draw, param.config);
        break;
      case 'createParticipant':
        if (actors.containsKey(actor!)) {
          _fail(
            "It is not possible to have actors with the same id, even if one is destroyed before the next is created. Use 'AS' aliases to simulate the behavior",
          );
        }
        _lastCreated = actor;
        addActor(actor, actor, param.description, param.draw, param.config);
        createdActors[actor] = messages.length;
        break;
      case 'destroyParticipant':
        _lastDestroyed = actor!;
        destroyedActors[actor] = messages.length;
        break;
      case 'activeStart':
      case 'activeEnd':
      case 'centralConnection':
      case 'centralConnectionReverse':
        addSignal(actor, null, null, param.signalType);
        break;
      case 'addNote':
        addNote(param.actor!, param.placement!, param.text!);
        break;
      case 'addLinks':
        addLinks(actor!, param.text!);
        break;
      case 'addALink':
        addALink(actor!, param.text!);
        break;
      case 'addProperties':
        addProperties(actor!, param.text!);
        break;
      case 'addDetails':
        addDetails(actor!, param.text!);
        break;
      case 'addMessage':
        if (_lastCreated != null) {
          if (param.to != _lastCreated) {
            _fail(
              'The created participant $_lastCreated does not have an associated creating message after its declaration. Please check the sequence diagram.',
            );
          }
          _lastCreated = null;
        } else if (_lastDestroyed != null) {
          if (param.to != _lastDestroyed && param.from != _lastDestroyed) {
            _fail(
              'The destroyed participant $_lastDestroyed does not have an associated destroying message after its declaration. Please check the sequence diagram.',
            );
          }
          _lastDestroyed = null;
        }
        addSignal(
          param.from,
          param.to,
          param.msg,
          param.signalType,
          param.activate ?? false,
          param.centralConnection,
        );
        break;
      case 'boxStart':
        addBox(param.boxData!);
        break;
      case 'boxEnd':
        _currentBox = null;
        break;
      case 'loopStart':
        addSignal(null, null, param.loopText as SeqText?, param.signalType);
        break;
      case 'rectStart':
        addSignal(null, null, param.color, param.signalType);
        break;
      case 'optStart':
        addSignal(null, null, param.optText, param.signalType);
        break;
      case 'altStart':
      case 'else':
        addSignal(null, null, param.altText, param.signalType);
        break;
      case 'parStart':
      case 'and':
        addSignal(null, null, param.parText, param.signalType);
        break;
      case 'criticalStart':
        addSignal(null, null, param.criticalText, param.signalType);
        break;
      case 'option':
        addSignal(null, null, param.optionText, param.signalType);
        break;
      case 'breakStart':
        addSignal(null, null, param.breakText, param.signalType);
        break;
      case 'loopEnd':
      case 'rectEnd':
      case 'optEnd':
      case 'altEnd':
      case 'parEnd':
      case 'criticalEnd':
      case 'breakEnd':
        addSignal(null, null, null, param.signalType);
        break;
    }
  }
}
