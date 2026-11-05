// Upstream: src/diagrams/git/db.ts

import '../../errors.dart';
import '../../preprocess.dart';
import 'parser.dart';

abstract final class CommitType {
  static const int normal = 0;
  static const int reverse = 1;
  static const int highlight = 2;
  static const int merge = 3;
  static const int cherryPick = 4;

  static const int NORMAL = 0;
  static const int REVERSE = 1;
  static const int HIGHLIGHT = 2;
  static const int MERGE = 3;
  static const int CHERRY_PICK = 4;
}

typedef GitDirection = String;

class GitCommit {
  GitCommit({
    required this.id,
    required this.message,
    required this.seq,
    required this.type,
    required this.tags,
    required this.parents,
    required this.branch,
    this.customType,
    this.customId,
  });

  final String id;
  final String message;
  final int seq;
  final int type;
  final List<String> tags;
  final List<String> parents;
  final String branch;
  final int? customType;
  final bool? customId;
}

class GitModel {
  const GitModel({
    this.type = 'gitGraph',
    this.title,
    this.accTitle,
    this.accDescr,
    required this.direction,
    required this.commits,
    required this.branches,
    required this.lanes,
    required this.currentBranch,
    required this.head,
    required this.warnings,
  });

  final String type;
  final String? title;
  final String? accTitle;
  final String? accDescr;
  final GitDirection direction;
  // Keyed by commit id, in the order the ids first appeared.
  final Map<String, GitCommit> commits;
  // The id of each branch's latest commit, or null while the branch has none.
  final Map<String, String?> branches;
  // Branch names in drawing order: by `order`, then by creation.
  final List<String> lanes;
  final String currentBranch;
  final GitCommit? head;
  final List<String> warnings;
}

class CommitDB {
  const CommitDB({required this.msg, this.id, required this.type, this.tags});

  final String msg;
  final String? id;
  final int type;
  final List<String>? tags;
}

class BranchDB {
  const BranchDB({required this.name, this.order});

  final String name;
  final int? order;
}

class MergeDB {
  const MergeDB({required this.branch, required this.id, this.type, this.tags});

  final String branch;
  final String id;
  final int? type;
  final List<String>? tags;
}

class CherryPickDB {
  const CherryPickDB({this.id, required this.targetId, this.parent, this.tags});

  final String? id;
  final String targetId;
  final String? parent;
  final List<String>? tags;
}

// The calls Mermaid's gitGraphParser makes on its database, under the same names.
abstract interface class GitDbParseProvider {
  void setDirection(GitDirection dir);
  void commit(CommitDB commit);
  void branch(BranchDB branch);
  void merge(MergeDB merge);
  void cherryPick(CherryPickDB cherryPick);
  void checkout(String branch);
}

Never _fail(String message) {
  throw PeleError(message, 'semantic', const PeleErrorInfo(type: 'gitGraph'));
}

int _typeCode(CommitTypeName name) {
  return name == 'REVERSE'
      ? CommitType.reverse
      : name == 'HIGHLIGHT'
      ? CommitType.highlight
      : CommitType.normal;
}

void populate(GitGraphAst ast, GitDbParseProvider db) {
  if (ast.dir != null && ast.dir!.isNotEmpty) {
    db.setDirection(ast.dir!);
  }
  for (final statement in ast.statements) {
    parseStatement(statement, db);
  }
}

void parseStatement(StatementAst statement, GitDbParseProvider db) {
  switch (statement) {
    case CommitAst():
      db.commit(
        CommitDB(
          id: statement.id,
          msg: statement.message ?? '',
          type: statement.type != null
              ? _typeCode(statement.type!)
              : CommitType.normal,
          tags: statement.tags,
        ),
      );
    case BranchAst():
      db.branch(BranchDB(name: statement.name, order: statement.order ?? 0));
    case MergeAst():
      db.merge(
        MergeDB(
          branch: statement.branch,
          id: statement.id ?? '',
          type: statement.type != null ? _typeCode(statement.type!) : null,
          tags: statement.tags,
        ),
      );
    case CheckoutAst():
      db.checkout(statement.branch);
    case CherryPickingAst():
      db.cherryPick(
        CherryPickDB(
          id: statement.id,
          targetId: '',
          tags: statement.tags.isEmpty ? null : statement.tags,
          parent: statement.parent,
        ),
      );
  }
}

class _GitDbProvider implements GitDbParseProvider {
  _GitDbProvider({
    required this.onSetDirection,
    required this.onCommit,
    required this.onBranch,
    required this.onMerge,
    required this.onCherryPick,
    required this.onCheckout,
  });

  final void Function(GitDirection) onSetDirection;
  final void Function(CommitDB) onCommit;
  final void Function(BranchDB) onBranch;
  final void Function(MergeDB) onMerge;
  final void Function(CherryPickDB) onCherryPick;
  final void Function(String) onCheckout;

  @override
  void setDirection(GitDirection dir) => onSetDirection(dir);

  @override
  void commit(CommitDB commit) => onCommit(commit);

  @override
  void branch(BranchDB branch) => onBranch(branch);

  @override
  void merge(MergeDB merge) => onMerge(merge);

  @override
  void cherryPick(CherryPickDB cherryPick) => onCherryPick(cherryPick);

  @override
  void checkout(String branch) => onCheckout(branch);
}

GitModel buildGit(GitGraphAst ast, Config config, String? title) {
  final git = config['gitGraph'] is Map ? asConfig(config['gitGraph']) : null;
  final mainName = git?['mainBranchName'] is String
      ? git!['mainBranchName'] as String
      : 'main';
  final mainOrder = git?['mainBranchOrder'] is int
      ? git!['mainBranchOrder'] as int
      : (git?['mainBranchOrder'] is double
            ? (git!['mainBranchOrder'] as double).toInt()
            : 0);

  final commits = <String, GitCommit>{};
  final branches = <String, String?>{mainName: null};
  final orders = <String, int?>{mainName: mainOrder};
  final warnings = <String>[];
  GitCommit? head;
  var current = mainName;
  GitDirection direction = 'LR';
  var seq = 0;

  // Mermaid appends seven random hex digits to the sequence number. These digits are derived
  // from the sequence number instead, so the same text always gives the same ids.
  String nextId() {
    for (var salt = seq + 1; ; salt = (salt + 0x9e3779b1) & 0xffffffff) {
      final hash = (((salt & 0xffffffff) * 0x9e3779b1) & 0xffffffff)
          .toRadixString(16)
          .padLeft(8, '0')
          .substring(0, 7);
      final id = '$seq-$hash';
      if (!commits.containsKey(id)) return id;
    }
  }

  void add(GitCommit commit) {
    head = commit;
    commits[commit.id] = commit;
    branches[current] = commit.id;
  }

  void checkout(String branch) {
    if (!branches.containsKey(branch)) {
      _fail(
        'Trying to checkout branch which is not yet created. (Help try using "branch $branch")',
      );
    }
    current = branch;
    final id = branches[branch];
    head = (id != null && id.isNotEmpty) ? commits[id] : null;
  }

  populate(
    ast,
    _GitDbProvider(
      onSetDirection: (dir) {
        direction = dir;
      },
      onCommit: (c) {
        final commit = GitCommit(
          id: (c.id != null && c.id!.isNotEmpty) ? c.id! : nextId(),
          message: c.msg,
          seq: seq++,
          type: c.type,
          tags: c.tags != null ? List<String>.of(c.tags!) : <String>[],
          parents: head == null ? <String>[] : <String>[head!.id],
          branch: current,
        );
        if (commits.containsKey(commit.id)) {
          warnings.add('Commit ID ${commit.id} already exists');
        }
        add(commit);
      },
      onBranch: (b) {
        if (branches.containsKey(b.name)) {
          _fail(
            'Trying to create an existing branch. (Help: Either use a new name if you want create a new branch or try using "checkout ${b.name}")',
          );
        }
        branches[b.name] = head?.id;
        orders[b.name] = b.order;
        checkout(b.name);
      },
      onMerge: (m) {
        final other = m.branch;
        final customId = m.id;
        final type = m.type;
        final tags = m.tags;
        final currentHead = branches[current];
        final otherHead = branches[other];
        final currentCommit = (currentHead != null && currentHead.isNotEmpty)
            ? commits[currentHead]
            : null;
        final otherCommit = (otherHead != null && otherHead.isNotEmpty)
            ? commits[otherHead]
            : null;
        if (currentCommit != null &&
            otherCommit != null &&
            currentCommit.branch == other) {
          _fail("Cannot merge branch '$other' into itself.");
        }
        if (current == other) {
          _fail('Incorrect usage of "merge". Cannot merge a branch to itself');
        }
        if (currentCommit == null) {
          _fail(
            'Incorrect usage of "merge". Current branch ($current)has no commits',
          );
        }
        if (!branches.containsKey(other)) {
          _fail(
            'Incorrect usage of "merge". Branch to be merged ($other) does not exist',
          );
        }
        if (otherCommit == null) {
          _fail(
            'Incorrect usage of "merge". Branch to be merged ($other) has no commits',
          );
        }
        if (identical(currentCommit, otherCommit)) {
          _fail('Incorrect usage of "merge". Both branches have same head');
        }
        if (customId.isNotEmpty && commits.containsKey(customId)) {
          _fail(
            'Incorrect usage of "merge". Commit with id:$customId already exists, use different custom id',
          );
        }
        add(
          GitCommit(
            id: customId.isNotEmpty ? customId : nextId(),
            message: 'merged branch $other into $current',
            seq: seq++,
            parents: head == null
                ? <String>[]
                : <String>[
                    head!.id,
                    (otherHead != null && otherHead.isNotEmpty)
                        ? otherHead
                        : '',
                  ],
            branch: current,
            type: CommitType.merge,
            customType: type,
            customId: customId.isNotEmpty,
            tags: tags != null ? List<String>.of(tags) : <String>[],
          ),
        );
      },
      onCherryPick: (cp) {
        final sourceId = cp.id;
        final targetId = cp.targetId;
        final tags = cp.tags;
        final parent = cp.parent;
        final source = (sourceId != null && sourceId.isNotEmpty)
            ? commits[sourceId]
            : null;
        if (source == null) {
          _fail(
            'Incorrect usage of "cherryPick". Source commit id should exist and provided',
          );
        }
        if (parent != null &&
            parent.isNotEmpty &&
            !source.parents.contains(parent)) {
          _fail(
            'Invalid operation: The specified parent commit is not an immediate parent of the cherry-picked commit.',
          );
        }
        if (source.type == CommitType.merge &&
            (parent == null || parent.isEmpty)) {
          _fail(
            'Incorrect usage of cherry-pick: If the source commit is a merge commit, an immediate parent commit must be specified.',
          );
        }
        if (targetId.isNotEmpty && commits.containsKey(targetId)) return;
        if (source.branch == current) {
          _fail(
            'Incorrect usage of "cherryPick". Source commit is already on current branch',
          );
        }
        final currentHead = branches[current];
        if (currentHead == null ||
            currentHead.isEmpty ||
            !commits.containsKey(currentHead)) {
          _fail(
            'Incorrect usage of "cherry-pick". Current branch ($current)has no commits',
          );
        }
        add(
          GitCommit(
            id: nextId(),
            message: 'cherry-picked ${source.message} into $current',
            seq: seq++,
            parents: head == null ? <String>[] : <String>[head!.id, source.id],
            branch: current,
            type: CommitType.cherryPick,
            tags: tags != null
                ? tags.where((t) => t.isNotEmpty).toList()
                : <String>[
                    'cherry-pick:${source.id}${source.type == CommitType.merge ? '|parent:$parent' : ''}',
                  ],
          ),
        );
      },
      onCheckout: checkout,
    ),
  );

  // A branch made without an order sorts by creation among those of order zero, as in Mermaid.
  final indexedOrders = <({String name, double order, int index})>[];
  var idx = 0;
  for (final entry in orders.entries) {
    indexedOrders.add((
      name: entry.key,
      order: entry.value?.toDouble() ?? double.parse('0.$idx'),
      index: idx,
    ));
    idx++;
  }
  indexedOrders.sort((a, b) {
    final cmp = a.order.compareTo(b.order);
    return cmp != 0 ? cmp : a.index - b.index;
  });
  final lanes = indexedOrders.map((b) => b.name).toList();

  return GitModel(
    title: (ast.title != null && ast.title!.isNotEmpty) ? ast.title : title,
    accTitle: (ast.accTitle != null && ast.accTitle!.isNotEmpty)
        ? ast.accTitle!.replaceFirst(RegExp(r'^\s+'), '')
        : null,
    accDescr: (ast.accDescr != null && ast.accDescr!.isNotEmpty)
        ? ast.accDescr!.replaceAll(RegExp(r'\n\s+'), '\n')
        : null,
    direction: direction,
    commits: commits,
    branches: branches,
    lanes: lanes,
    currentBranch: current,
    head: head,
    warnings: warnings,
  );
}
