// Upstream: src/diagrams/class/members.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import '../common/generics.dart';

typedef Visibility = String;

bool _isVisibility(String ch) {
  return ch == '#' || ch == '+' || ch == '~' || ch == '-';
}

class ClassMember {
  String id = '';
  String memberType;
  Visibility visibility = '';
  String classifier = '';
  String parameters = '';
  String returnType = '';

  ClassMember(String input, this.memberType) {
    // Mermaid throws a TypeError for a method with no opening parenthesis, such as `run)`.
    // It is kept here as an attribute, so it is shown as written.
    if (memberType != 'method' || !_parseMethod(input)) {
      _parseAttribute(input);
    }
    id = id.startsWith(' ') ? ' ${id.trim()}' : id.trim();
  }

  // The same split as Mermaid's /([#+~-])?(.+)\((.*)\)([\s$*])?(.*)([$*])?/, found in one pass:
  // the first line with an opening parenthesis after its first character and a closing one later.
  bool _parseMethod(String input) {
    final n = input.length;
    for (var start = 0; start < n;) {
      var end = start;
      while (end < n && !isLineEnd(charCodeAt(input, end))) {
        end++;
      }
      var close = end - 1;
      while (close > start && charCodeAt(input, close) != 41) {
        close--;
      }
      var open = close - 1;
      while (open > start && charCodeAt(input, open) != 40) {
        open--;
      }
      if (open > start) {
        final first = input[start];
        final visible = _isVisibility(first) && open > start + 1;
        if (visible) visibility = first;
        id = sliceJs(input, visible ? start + 1 : start, open);
        parameters = sliceJs(input, open + 1, close).trim();
        var rest = close + 1;
        var cls = '';
        if (rest < n) {
          final next = input[rest];
          if (next == r'$' || next == '*' || next.trim().isEmpty) {
            cls = next.trim();
            rest++;
          }
        }
        var stop = rest;
        while (stop < n && !isLineEnd(charCodeAt(input, stop))) {
          stop++;
        }
        returnType = sliceJs(input, rest, stop).trim();
        if (cls.isEmpty) {
          final last = sliceJs(returnType, -1);
          if (last == r'$' || last == '*') {
            cls = last;
            returnType = sliceJs(returnType, 0, -1);
          }
        }
        classifier = cls;
        return true;
      }
      start = end + 1;
    }
    memberType = 'attribute';
    return false;
  }

  void _parseAttribute(String input) {
    final first = sliceJs(input, 0, 1);
    final last = sliceJs(input, -1);
    if (_isVisibility(first)) visibility = first;
    if (last == r'$' || last == '*') classifier = last;
    final from = visibility.isEmpty ? 0 : 1;
    final to = classifier.isEmpty ? input.length : input.length - 1;
    id = to >= from ? input.substring(from, to) : input.substring(to, from);
  }

  ({String displayText, String cssStyle}) getDisplayDetails() {
    var displayText = '$visibility${parseGenericTypes(id)}';
    if (memberType == 'method') {
      displayText += '(${parseGenericTypes(parameters.trim())})';
      if (returnType.isNotEmpty) {
        displayText += ' : ${parseGenericTypes(returnType)}';
      }
    }
    return (displayText: displayText.trim(), cssStyle: parseClassifier());
  }

  String parseClassifier() {
    return classifier == '*'
        ? 'font-style:italic;'
        : classifier == r'$'
        ? 'text-decoration:underline;'
        : '';
  }
}
