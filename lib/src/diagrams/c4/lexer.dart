// Upstream: src/diagrams/c4/lexer.ts

import '../../util/chars.dart';
import '../../util/math_js.dart';
import 'tokens.dart';

// Token text is src.slice(starts[i], ends[i]); nothing is copied until the parser asks for it.
class C4Tokens {
  const C4Tokens({
    required this.types,
    required this.starts,
    required this.ends,
  });

  final List<int> types;
  final List<int> starts;
  final List<int> ends;
}

abstract final class _S {
  static const int initial = 0;
  static const int struct = 1;
  static const int attribute = 2;
  static const int string = 3;
  static const int stringKv = 4;
  static const int stringKvKey = 5;
  static const int stringKvValue = 6;
  static const int acc = 7;
  static const int accDescrMultiline = 8;
}

const Map<String, int> _keywords = <String, int>{
  'C4Context': T.C4_CONTEXT,
  'C4Container': T.C4_CONTAINER,
  'C4Component': T.C4_COMPONENT,
  'C4Dynamic': T.C4_DYNAMIC,
  'C4Deployment': T.C4_DEPLOYMENT,
  'Person': T.PERSON,
  'Person_Ext': T.PERSON_EXT,
  'System': T.SYSTEM,
  'SystemDb': T.SYSTEM_DB,
  'SystemQueue': T.SYSTEM_QUEUE,
  'System_Ext': T.SYSTEM_EXT,
  'SystemDb_Ext': T.SYSTEM_EXT_DB,
  'SystemQueue_Ext': T.SYSTEM_EXT_QUEUE,
  'Container': T.CONTAINER,
  'ContainerDb': T.CONTAINER_DB,
  'ContainerQueue': T.CONTAINER_QUEUE,
  'Container_Ext': T.CONTAINER_EXT,
  'ContainerDb_Ext': T.CONTAINER_EXT_DB,
  'ContainerQueue_Ext': T.CONTAINER_EXT_QUEUE,
  'Component': T.COMPONENT,
  'ComponentDb': T.COMPONENT_DB,
  'ComponentQueue': T.COMPONENT_QUEUE,
  'Component_Ext': T.COMPONENT_EXT,
  'ComponentDb_Ext': T.COMPONENT_EXT_DB,
  'ComponentQueue_Ext': T.COMPONENT_EXT_QUEUE,
  'Enterprise_Boundary': T.ENTERPRISE_BOUNDARY,
  'System_Boundary': T.SYSTEM_BOUNDARY,
  'Boundary': T.BOUNDARY,
  'Container_Boundary': T.CONTAINER_BOUNDARY,
  'Deployment_Node': T.NODE,
  'Node': T.NODE,
  'Node_L': T.NODE_L,
  'Node_R': T.NODE_R,
  'Rel': T.REL,
  'BiRel': T.BIREL,
  'Rel_Up': T.REL_U,
  'Rel_U': T.REL_U,
  'Rel_Down': T.REL_D,
  'Rel_D': T.REL_D,
  'Rel_Left': T.REL_L,
  'Rel_L': T.REL_L,
  'Rel_Right': T.REL_R,
  'Rel_R': T.REL_R,
  'Rel_Back': T.REL_B,
  'RelIndex': T.REL_INDEX,
  'UpdateElementStyle': T.UPDATE_EL_STYLE,
  'UpdateRelStyle': T.UPDATE_REL_STYLE,
  'UpdateLayoutConfig': T.UPDATE_LAYOUT_CONFIG,
};

final List<RegExp> _reDirection = <RegExp>[
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+TB[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+BT[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+RL[^\n]*'),
  RegExp(r'[^\n\r\u2028\u2029]*direction\s+LR[^\n]*'),
];

// Consume line breaks too: the grammar rejects blank statements.
final RegExp _reBareTitle = RegExp(r'title[^\S\r\n]*(?=[\r\n]|$)\s*');

// Follows the lexer Jison compiles from c4Diagram.jison: its rule order, its start conditions,
// and what it returns once the input runs out in each of them.
C4Tokens tokenize(String src) {
  final n = src.length;
  final types = <int>[];
  final starts = <int>[];
  final ends = <int>[];
  var state = _S.initial;
  var accValue = T.acc_title_value;
  var p = 0;
  var done = false;
  // Where the next `direction` is; -2 until the first search.
  var dirNext = -2;
  var lineEnd = -1;
  var dirFailed = 0;

  void emit(int type, int s, int e) {
    types.add(type);
    starts.add(s);
    ends.add(e);
    p = e;
  }

  int skipWs(int q) {
    while (q < n && isSpace(charCodeAt(src, q))) {
      q++;
    }
    return q;
  }

  int upTo(String ch, int from) {
    final q = src.indexOf(ch, from);
    return q == -1 ? n : q;
  }

  // `word\s[^#\n;]+`
  bool statement(String word, int type) {
    var q = p + word.length;
    if (!src.startsWith(word, p) || !isSpace(charCodeAt(src, q))) return false;
    final from = ++q;
    while (q < n) {
      final c = charCodeAt(src, q);
      if (c == 35 || c == 10 || c == 59) break;
      q++;
    }
    if (q == from) return false;
    emit(type, p, q);
    return true;
  }

  for (;;) {
    // Jison notes the end of input one call before it reports it, so a rule that matches
    // nothing gets one last turn.
    if (done) {
      emit(T.END, n, n);
      break;
    }
    if (p >= n) done = true;
    final c = charCodeAt(src, p);

    if (state == _S.initial) {
      if (p >= n) {
        emit(T.EOF, n, n);
        continue;
      }
      if (dirNext != -1 && p >= dirFailed) {
        if (dirNext < p) dirNext = src.indexOf('direction', p);
        if (dirNext != -1) {
          if (lineEnd < p) {
            var q = p;
            while (q < n && !isLineEnd(src.codeUnitAt(q))) {
              q++;
            }
            lineEnd = q;
          }
          if (dirNext < lineEnd) {
            var matched = false;
            for (var i = 0; i < 4 && !matched; i++) {
              final end = matchSticky(_reDirection[i], src, p);
              if (end != -1) {
                emit(T.direction_tb + i, p, end);
                matched = true;
              }
            }
            if (matched) continue;
            // No direction statement starts anywhere in the rest of this line either.
            dirFailed = lineEnd;
          }
        }
      }
      if (c == 116) {
        final bareEnd = matchSticky(_reBareTitle, src, p);
        if (bareEnd != -1) {
          p = bareEnd;
          continue;
        }
        if (statement('title', T.title)) continue;
      }
      if (c == 97) {
        if (statement('accDescription', T.accDescription)) continue;
        final title = src.startsWith('accTitle', p);
        if (title || src.startsWith('accDescr', p)) {
          final q = skipWs(p + 8);
          final d = charCodeAt(src, q);
          if (d == 58) {
            emit(title ? T.acc_title : T.acc_descr, p, skipWs(q + 1));
            accValue = title ? T.acc_title_value : T.acc_descr_value;
            state = _S.acc;
            continue;
          }
          if (d == 123 && !title) {
            p = skipWs(q + 1);
            state = _S.accDescrMultiline;
            continue;
          }
        }
      }
      if (c == 37 && charCodeAt(src, p + 1) == 37) {
        // A comment takes the line breaks after it, so no NEWLINE follows.
        var q = upTo('\n', p + 2);
        while (q < n &&
            (charCodeAt(src, q) == 10 || charCodeAt(src, q) == 13)) {
          q++;
        }
        p = q;
        continue;
      }
      if (isSpace(c)) {
        var q = p;
        var last = -1;
        while (q < n) {
          final d = charCodeAt(src, q);
          if (!isSpace(d)) break;
          if (d == 10) last = q;
          q++;
        }
        if (last != -1) {
          emit(T.NEWLINE, p, last + 1);
        } else {
          p = q;
        }
        continue;
      }
      if (c == 123) {
        emit(T.LBRACE, p, p + 1);
        continue;
      }
      if (c == 125) {
        emit(T.RBRACE, p, p + 1);
        continue;
      }
      if (isWord(c)) {
        var q = p + 1;
        while (q < n && isWord(charCodeAt(src, q))) {
          q++;
        }
        final type = q - p <= 19 ? _keywords[src.substring(p, q)] : null;
        if (type != null) {
          if (type > T.C4_DEPLOYMENT) state = _S.struct;
          emit(type, p, q);
          continue;
        }
      }
      emit(T.ERROR, p, p);
      break;
    }

    if (state == _S.struct) {
      if (p >= n) {
        emit(T.EOF_IN_STRUCT, n, n);
      } else if (c == 40) {
        var q = p + 1;
        while (charCodeAt(src, q) == 32) {
          q++;
        }
        if (charCodeAt(src, q) == 44) {
          emit(T.ATTRIBUTE_EMPTY, p, q + 1);
        } else {
          p++;
        }
        state = _S.attribute;
      } else if (c == 41) {
        p++;
        state = _S.initial;
      } else {
        emit(T.ERROR, p, p);
        break;
      }
      continue;
    }

    if (state == _S.attribute) {
      if (p >= n) continue;
      if (c == 41) {
        p++;
        state = _S.initial;
      } else if (c == 44) {
        if (charCodeAt(src, p + 1) == 44) {
          emit(T.ATTRIBUTE_EMPTY, p, p + 2);
        } else {
          p++;
        }
      } else {
        var q = p;
        while (charCodeAt(src, q) == 32) {
          q++;
        }
        final d = charCodeAt(src, q);
        if (d == 34) {
          if (charCodeAt(src, q + 1) == 34) {
            emit(T.ATTRIBUTE_EMPTY, p, q + 2);
          } else {
            p = q + 1;
            state = _S.string;
          }
        } else if (d == 36) {
          p = q + 1;
          state = _S.stringKv;
        } else {
          // An unquoted value runs to the next comma, through closing parentheses and line breaks.
          emit(T.STR, p, upTo(',', p));
        }
      }
      continue;
    }

    if (state == _S.string) {
      if (c == 34) {
        p++;
        state = _S.attribute;
      } else {
        emit(T.STR, p, upTo('"', p));
      }
      continue;
    }

    if (state == _S.stringKv) {
      emit(T.STR_KEY, p, upTo('=', p));
      state = _S.stringKvKey;
      continue;
    }

    if (state == _S.stringKvKey) {
      if (p >= n) continue;
      var q = p + 1;
      if (c == 61) {
        while (charCodeAt(src, q) == 32) {
          q++;
        }
      }
      if (c != 61 || charCodeAt(src, q) != 34) {
        emit(T.ERROR, p, p);
        break;
      }
      p = q + 1;
      state = _S.stringKvValue;
      continue;
    }

    if (state == _S.stringKvValue) {
      if (p >= n) continue;
      if (c == 34) {
        p++;
        state = _S.attribute;
      } else {
        emit(T.STR_VALUE, p, upTo('"', p));
      }
      continue;
    }

    if (state == _S.acc) {
      emit(accValue, p, upTo('\n', p));
      state = _S.initial;
      continue;
    }

    if (c == 125) {
      p++;
      state = _S.initial;
    } else {
      emit(T.acc_descr_multiline_value, p, upTo('}', p));
    }
  }

  return C4Tokens(types: types, starts: starts, ends: ends);
}
