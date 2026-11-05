// Upstream: src/diagrams/block/db.ts

import 'dart:math' as math;

import '../../errors.dart';
import 'types.dart';

class BlockDbOptions {
  final void Function(String message)? warn;

  const BlockDbOptions({this.warn});
}

const int _maxSpaces = 100000;

String typeStr2Type(String? typeStr) {
  switch (typeStr) {
    case '[]':
      return 'square';
    case '()':
      return 'round';
    case '(())':
      return 'circle';
    case '>]':
      return 'rect_left_inv_arrow';
    case '{}':
      return 'diamond';
    case '{{}}':
      return 'hexagon';
    case '([])':
      return 'stadium';
    case '[[]]':
      return 'subroutine';
    case '[()]':
      return 'cylinder';
    case '((()))':
      return 'doublecircle';
    case '[//]':
      return 'lean_right';
    case r'[\\]':
      return 'lean_left';
    case r'[/\]':
      return 'trapezoid';
    case r'[\/]':
      return 'inv_trapezoid';
    case '<[]>':
      return 'block_arrow';
    default:
      return 'na';
  }
}

String edgeStrToEdgeData(String typeStr) {
  final trimmed = typeStr.trim();
  final last = trimmed.isEmpty ? '' : trimmed[trimmed.length - 1];
  switch (last) {
    case 'x':
      return 'arrow_cross';
    case 'o':
      return 'arrow_circle';
    case '>':
      return 'arrow_point';
    default:
      return '';
  }
}

String edgeStrToEdgeStartData(String typeStr) {
  final trimmed = typeStr.trim();
  final first = trimmed.isEmpty ? '' : trimmed[0];
  switch (first) {
    case 'x':
      return 'arrow_cross';
    case 'o':
      return 'arrow_circle';
    case '<':
      return 'arrow_point';
    default:
      return 'arrow_open';
  }
}

String edgeStrToThickness(String typeStr) {
  return typeStr.contains('==') ? 'thick' : 'normal';
}

String edgeStrToPattern(String typeStr) {
  return typeStr.contains('.-') ? 'dotted' : 'solid';
}

class _Frame {
  final List<Block> list;
  int at = 0;
  final Block parent;
  final List<Block> children = <Block>[];
  final int columns;

  _Frame({required this.list, required this.parent, required this.columns});
}

List<Block> _flattenStatements(List<Statement> statements) {
  final out = <Block>[];
  for (final s in statements) {
    if (s is Block) {
      out.add(s);
    } else if (s is List) {
      for (final item in s) {
        if (item is Block) out.add(item);
      }
    }
  }
  return out;
}

_Frame _frame(List<Statement> statements, Block parent) {
  final list = _flattenStatements(statements);
  var columns = -1;
  for (final block in list) {
    if (block.type == 'column-setting') {
      columns = block.columns ?? -1;
      break;
    }
  }
  return _Frame(list: list, parent: parent, columns: columns);
}

class BlockDb implements BlockModel {
  @override
  final String type = 'block';
  @override
  String? title;
  @override
  String? accTitle;
  @override
  String? accDescr;
  @override
  Block root = Block(
    id: 'root',
    type: 'composite',
    children: <Block>[],
    columns: -1,
  );
  @override
  List<Block> blocks = <Block>[];
  @override
  List<Block> edges = <Block>[];
  @override
  Map<String, BlockClassDef> classes = <String, BlockClassDef>{};
  // Mermaid keeps the root in here too, which makes a block called `root` vanish. Here it stays out.
  @override
  Map<String, Block> byId = <String, Block>{};

  final void Function(String message)? _warn;
  // Ids that a class or style statement named before any block had them.
  final Set<String> _pending = <String>{};
  final Map<String, int> _edgeCount = <String, int>{};
  int _ids = 0;
  int _colors = 0;
  int _spaces = 0;

  BlockDb([BlockDbOptions options = const BlockDbOptions()])
    : _warn = options.warn;

  String typeStr2TypeFn(String? typeStr) => typeStr2Type(typeStr);
  String edgeStrToEdgeDataFn(String typeStr) => edgeStrToEdgeData(typeStr);
  String edgeStrToEdgeStartDataFn(String typeStr) =>
      edgeStrToEdgeStartData(typeStr);
  String edgeStrToThicknessFn(String typeStr) => edgeStrToThickness(typeStr);
  String edgeStrToPatternFn(String typeStr) => edgeStrToPattern(typeStr);

  // Mermaid's ids are random. These are counted, so the same text always gives the same output.
  String generateId() {
    return 'id-${++_ids}';
  }

  void addStyleClass(String id, [String? styleAttributes]) {
    final attrs = styleAttributes ?? '';
    var found = classes[id];
    if (found == null) {
      found = BlockClassDef(id: id);
      classes[id] = found;
    }
    for (final attribute in attrs.split(',')) {
      final semi = attribute.indexOf(';');
      final fixed =
          (semi == -1
                  ? attribute
                  : attribute.substring(0, semi) +
                        attribute.substring(semi + 1))
              .trim();
      if (attribute.contains('color')) {
        found.textStyles.add(
          fixed.replaceFirst('fill', 'bgFill').replaceFirst('color', 'fill'),
        );
      }
      found.styles.add(fixed);
    }
  }

  void addStyle2Node(String id, [String styles = '']) {
    _named(id).styles = styles.split(',');
  }

  // Mermaid looks each id up before trimming it, so `class a, b hot` misses b. Here it is trimmed first.
  void setCssClass(String itemIds, String cssClassName) {
    for (final id in itemIds.split(',')) {
      final block = _named(id.trim());
      (block.classes ??= <String>[]).add(cssClassName);
    }
  }

  // Mermaid throws on a style for an unknown id, and a class for one makes the block of that id
  // disappear when it is declared later. Here both wait for the block.
  Block _named(String id) {
    var block = byId[id];
    if (block == null) {
      block = Block(id: id, type: 'na', children: <Block>[]);
      byId[id] = block;
      _pending.add(id);
    }
    return block;
  }

  void setHierarchy(List<Statement> statements) {
    final stack = <_Frame>[_frame(statements, root)];
    while (stack.isNotEmpty) {
      final f = stack.last;
      if (f.at == f.list.length) {
        f.parent.children = f.children;
        stack.removeLast();
        continue;
      }
      final block = f.list[f.at++];
      if (f.columns > 0 &&
          block.type != 'column-setting' &&
          block.widthInColumns != null &&
          block.widthInColumns! > f.columns) {
        _warn?.call(
          'Block ${block.id} width ${block.widthInColumns} exceeds configured column width ${f.columns}',
        );
      }
      switch (block.type) {
        case 'classDef':
          addStyleClass(block.id, block.css);
          continue;
        case 'applyClass':
          setCssClass(block.id, block.styleClass ?? '');
          continue;
        case 'applyStyles':
          if (block.stylesStr != null && block.stylesStr!.isNotEmpty) {
            addStyle2Node(block.id, block.stylesStr!);
          }
          continue;
        case 'column-setting':
          f.parent.columns = block.columns ?? -1;
          continue;
        case 'edge':
          final count = (_edgeCount[block.id] ?? 0) + 1;
          _edgeCount[block.id] = count;
          block.id = '$count-${block.id}';
          edges.add(block);
          continue;
      }

      // A composite whose header was a link statement has no id of its own.
      if (block.id.isEmpty) block.id = generateId();
      if (block.label == null || block.label!.isEmpty) {
        block.label = block.type == 'composite' ? '' : block.id;
      }
      final known = byId[block.id];
      final fresh = known == null || _pending.remove(block.id);
      if (!fresh) {
        if (block.type != 'na') known.type = block.type;
        if (block.label != block.id) known.label = block.label;
      } else {
        if (known != null) {
          block.classes = known.classes;
          block.styles = known.styles;
        }
        if (block.type == 'composite') block.colorIndex = _colors++;
        byId[block.id] = block;
      }

      final inner = block.children;
      block.children = <Block>[];
      if (block.type == 'space') {
        final width = block.width ?? 1;
        if (!(width <= _maxSpaces - _spaces)) {
          throw PeleError(
            'A block diagram can hold at most $_maxSpaces space blocks.',
            'limit',
            const PeleErrorInfo(type: 'block'),
          );
        }
        _spaces += math.max<int>(width, 0);
        for (var j = 0; j < width; j++) {
          final copy = block.copyWith(
            id: '${block.id}-$j',
            children: <Block>[],
          );
          byId[copy.id] = copy;
          f.children.add(copy);
        }
      } else if (fresh) {
        f.children.add(block);
      }
      if (inner != null && inner.isNotEmpty) {
        stack.add(_frame(inner, block));
      }
    }
    blocks = root.blockChildren;
  }
}
