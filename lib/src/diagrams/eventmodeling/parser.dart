// Upstream: src/diagrams/eventmodeling/parser.ts

import '../common/acc_descr.dart';
import '../common/tokens.dart';

final TokenType _emId = TokenType(
  name: 'EM_ID',
  pattern: RegExp(r'[_a-zA-Z][\w_]*'),
);

// Langium gives every keyword that is also an identifier the identifier as a longer alternative.
TokenType _word(String text) =>
    TokenType(name: text, pattern: text, longer: <TokenType>[_emId]);

TokenType _sign(String text) => TokenType(name: text, pattern: text);

const List<String> _words = <String>[
  'resetframe',
  'readmodel',
  'processor',
  'timeframe',
  'command',
  'entity',
  'event',
  'jsobj',
  'figma',
  'given',
  'json',
  'salt',
  'html',
  'text',
  'data',
  'note',
  'when',
  'then',
  'rmo',
  'cmd',
  'evt',
  'pcr',
  'uri',
];

final TokenType _kwEm = keyword('eventmodeling');
final TokenType _titleBeforeWord = titleBefore(r'\w');

final List<TokenType> EVENTMODELING_TOKENS = <TokenType>[
  TokenType(
    name: _kwEm.name,
    pattern: _kwEm.pattern,
    first: _kwEm.first,
    longer: <TokenType>[_emId],
  ),
  for (final w in _words) _word(w),
  _sign('->>'),
  _word('gwt'),
  _word('ui'),
  _word('md'),
  _word('tf'),
  _sign('[['),
  _sign(']]'),
  _word('rf'),
  _sign('`'),
  _sign('.'),
  _emId,
  TokenType(name: 'EM_FID', pattern: RegExp(r'\d{1,3}')),
  TokenType(
    name: 'EM_DATA_INLINE',
    pattern: RegExp(
      r'\{(.*)\}|"(.*)"|'
      "'"
      r"'(.*)'",
    ),
  ),
  TokenType(
    name: 'EM_DATA_BLOCK',
    pattern: RegExp(r'\{[\t ]*\r?\n(?:[\S\s]*?\r?\n)?\}(?:\r?\n|(?!\S))'),
  ),
  accDescr('EM_ACC_DESCR'),
  TokenType(
    name: 'EM_ACC_TITLE',
    pattern: ACC_TITLE.pattern,
    first: ACC_TITLE.first,
  ),
  TokenType(
    name: 'EM_TITLE',
    pattern: _titleBeforeWord.pattern,
    first: _titleBeforeWord.first,
  ),
  TokenType(name: 'EM_WS', pattern: RegExp(r'\s+'), hidden: true),
  TokenType(
    name: 'EM_YAML',
    pattern: YAML.pattern,
    hidden: YAML.hidden,
    opener: YAML.opener,
    first: YAML.first,
  ),
  TokenType(
    name: 'EM_DIRECTIVE',
    pattern: DIRECTIVE.pattern,
    hidden: DIRECTIVE.hidden,
    opener: DIRECTIVE.opener,
    first: DIRECTIVE.first,
  ),
  TokenType(
    name: 'EM_SINGLE_LINE_COMMENT',
    pattern: SINGLE_LINE_COMMENT.pattern,
    first: SINGLE_LINE_COMMENT.first,
    hidden: SINGLE_LINE_COMMENT.hidden,
  ),
  TokenType(
    name: 'EM_ML_COMMENT',
    pattern: RegExp(r'\/\*[\s\S]*?\*\/'),
    hidden: true,
  ),
  TokenType(
    name: 'EM_SL_COMMENT',
    pattern: RegExp(r'\/\/[^\n\r]*'),
    hidden: true,
  ),
];

int _index(String name) =>
    EVENTMODELING_TOKENS.indexWhere((t) => t.name == name);
Set<int> _kinds(List<String> names) => names.map(_index).toSet();

class _T {
  static final int keyword = 0;
  static final int arrow = _index('->>');
  static final int open = _index('[[');
  static final int close = _index(']]');
  static final int tick = _index('`');
  static final int dot = _index('.');
  static final int id = _index('EM_ID');
  static final int frameId = _index('EM_FID');
  static final int inline = _index('EM_DATA_INLINE');
  static final int block = _index('EM_DATA_BLOCK');
  static final int accDescr = _index('EM_ACC_DESCR');
  static final int accTitle = _index('EM_ACC_TITLE');
  static final int title = _index('EM_TITLE');
  static final int entity = _index('entity');
  static final int data = _index('data');
  static final int note = _index('note');
  static final int gwt = _index('gwt');
  static final int given = _index('given');
  static final int when = _index('when');
  static final int then = _index('then');
}

final Set<int> _timeFrame = _kinds(<String>['tf', 'timeframe']);
final Set<int> _resetFrame = _kinds(<String>['rf', 'resetframe']);
final Set<int> _entityType = _kinds(<String>[
  'rmo',
  'readmodel',
  'ui',
  'cmd',
  'command',
  'evt',
  'event',
  'pcr',
  'processor',
]);
final Set<int> _dataType = _kinds(<String>[
  'json',
  'jsobj',
  'figma',
  'salt',
  'uri',
  'md',
  'html',
  'text',
]);

// A cross-reference as Mermaid reads it: by its text, never linked.
class Ref {
  final String $refText;

  const Ref({required this.$refText});
}

class EmFrame {
  final String $type;
  String name;
  String modelEntityType;
  String entityIdentifier;
  final List<Ref> sourceFrames;
  Ref? dataReference;
  String? dataType;
  String? dataInlineValue;
  // Offset of the frame in the source, for error messages.
  final int $offset;

  EmFrame({
    required this.$type,
    this.name = '',
    this.modelEntityType = '',
    this.entityIdentifier = '',
    List<Ref>? sourceFrames,
    this.dataReference,
    this.dataType,
    this.dataInlineValue,
    required this.$offset,
  }) : sourceFrames = sourceFrames ?? <Ref>[];
}

class EmDataEntity {
  final String $type = 'EmDataEntity';
  final String name;
  String? dataType;
  String dataBlockValue;

  EmDataEntity({required this.name, this.dataType, this.dataBlockValue = ''});
}

class EmNoteEntity {
  final String $type = 'EmNoteEntity';
  final Ref sourceFrame;
  String? dataType;
  String dataBlockValue;

  EmNoteEntity({
    required this.sourceFrame,
    this.dataType,
    this.dataBlockValue = '',
  });
}

class EmGwtStatement {
  final String $type = 'EmGwtStatement';
  final Ref entityIdentifier;

  const EmGwtStatement({required this.entityIdentifier});
}

class EmGwt {
  final String $type = 'EmGwt';
  final Ref sourceFrame;
  List<EmGwtStatement> givenStatements;
  List<EmGwtStatement> whenStatements;
  List<EmGwtStatement> thenStatements;

  EmGwt({
    required this.sourceFrame,
    List<EmGwtStatement>? givenStatements,
    List<EmGwtStatement>? whenStatements,
    List<EmGwtStatement>? thenStatements,
  }) : givenStatements = givenStatements ?? <EmGwtStatement>[],
       whenStatements = whenStatements ?? <EmGwtStatement>[],
       thenStatements = thenStatements ?? <EmGwtStatement>[];
}

class EmModelEntityAst {
  final String $type = 'EmModelEntity';
  final String name;

  const EmModelEntityAst({required this.name});
}

class EventModelAst {
  final String $type = 'EventModel';
  // The whole token, keyword included: the grammar's own terminals get no value conversion.
  String? title;
  String? accTitle;
  String? accDescr;
  final List<EmModelEntityAst> modelEntities;
  final List<EmFrame> frames;
  final List<EmDataEntity> dataEntities;
  final List<EmNoteEntity> noteEntities;
  final List<EmGwt> gwtEntities;
  final String $source;

  EventModelAst({
    this.title,
    this.accTitle,
    this.accDescr,
    List<EmModelEntityAst>? modelEntities,
    List<EmFrame>? frames,
    List<EmDataEntity>? dataEntities,
    List<EmNoteEntity>? noteEntities,
    List<EmGwt>? gwtEntities,
    required this.$source,
  }) : modelEntities = modelEntities ?? <EmModelEntityAst>[],
       frames = frames ?? <EmFrame>[],
       dataEntities = dataEntities ?? <EmDataEntity>[],
       noteEntities = noteEntities ?? <EmNoteEntity>[],
       gwtEntities = gwtEntities ?? <EmGwt>[];
}

EventModelAst parseEventModel(String src) {
  final r = Reader(
    tokenize(src, EVENTMODELING_TOKENS, 'eventmodeling'),
    EVENTMODELING_TOKENS,
    'eventmodeling',
  );
  final ast = EventModelAst($source: src);

  bool at(int kind) => r.kinds[r.i] == kind;
  String one(Set<int> set, String expected) =>
      set.contains(r.kinds[r.i]) ? r.take() : r.fail(expected);
  String qualifiedName() {
    var name = r.expect(_T.id);
    while (r.accept(_T.dot)) {
      name += '.${r.expect(_T.id)}';
    }
    return name;
  }

  String? dataType() {
    if (!r.accept(_T.tick)) return null;
    final type = one(_dataType, 'a data type');
    r.expect(_T.tick);
    return type;
  }

  List<EmGwtStatement> statements() {
    final out = <EmGwtStatement>[];
    do {
      one(_entityType, 'an entity type');
      out.add(EmGwtStatement(entityIdentifier: Ref($refText: r.expect(_T.id))));
    } while (_entityType.contains(r.kinds[r.i]));
    return out;
  }

  r.expect(_T.keyword);
  while (!at(-1)) {
    final kind = r.kinds[r.i];
    if (kind == _T.accDescr) {
      ast.accDescr = r.take();
    } else if (kind == _T.accTitle) {
      ast.accTitle = r.take();
    } else if (kind == _T.title) {
      ast.title = r.take();
    } else if (kind == _T.entity) {
      r.i++;
      ast.modelEntities.add(EmModelEntityAst(name: qualifiedName()));
    } else if (_timeFrame.contains(kind) || _resetFrame.contains(kind)) {
      final frame = EmFrame(
        $type: _timeFrame.contains(kind) ? 'EmTimeFrame' : 'EmResetFrame',
        $offset: r.tokens.starts[r.i],
      );
      r.i++;
      frame.name = r.expect(_T.frameId);
      frame.modelEntityType = one(_entityType, 'an entity type');
      frame.entityIdentifier = qualifiedName();
      while (r.accept(_T.arrow)) {
        frame.sourceFrames.add(Ref($refText: r.expect(_T.frameId)));
      }
      if (r.accept(_T.open)) {
        frame.dataReference = Ref($refText: r.expect(_T.id));
        r.expect(_T.close);
      }
      if (at(_T.tick) || at(_T.inline)) {
        final type = dataType();
        if (type != null) frame.dataType = type;
        frame.dataInlineValue = r.expect(_T.inline);
      }
      ast.frames.add(frame);
    } else if (kind == _T.data) {
      r.i++;
      final entity = EmDataEntity(name: r.expect(_T.id));
      final type = dataType();
      if (type != null) entity.dataType = type;
      entity.dataBlockValue = r.expect(_T.block);
      ast.dataEntities.add(entity);
    } else if (kind == _T.note) {
      r.i++;
      final note = EmNoteEntity(
        sourceFrame: Ref($refText: r.expect(_T.frameId)),
      );
      final type = dataType();
      if (type != null) note.dataType = type;
      note.dataBlockValue = r.expect(_T.block);
      ast.noteEntities.add(note);
    } else if (kind == _T.gwt) {
      r.i++;
      final gwt = EmGwt(sourceFrame: Ref($refText: r.expect(_T.frameId)));
      r.expect(_T.given);
      gwt.givenStatements = statements();
      if (r.accept(_T.when)) gwt.whenStatements = statements();
      r.expect(_T.then);
      gwt.thenStatements = statements();
      ast.gwtEntities.add(gwt);
    } else {
      r.fail('a frame, an entity, a data block, a note, or a specification');
    }
  }
  return ast;
}
