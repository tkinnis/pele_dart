// Upstream: src/diagrams/cynefin/model.ts

import '../../svg/root.dart';
import 'parser.dart';

export 'parser.dart' show DomainName;

class CynefinItem {
  final String label;

  const CynefinItem({required this.label});
}

class CynefinDomain {
  final DomainName name;
  final List<CynefinItem> items;

  const CynefinDomain({required this.name, required this.items});
}

class CynefinTransition {
  final DomainName from;
  final DomainName to;
  final String? label;

  const CynefinTransition({required this.from, required this.to, this.label});
}

class CynefinModel implements RootModel {
  final String type = 'cynefin';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  // The domains the source declares. All five are drawn either way.
  final Map<DomainName, CynefinDomain> domains;
  final List<CynefinTransition> transitions;

  const CynefinModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required this.domains,
    required this.transitions,
  });
}

class CynefinDb {
  final Map<DomainName, CynefinDomain> domains = <DomainName, CynefinDomain>{};
  List<CynefinTransition> transitions = <CynefinTransition>[];

  // A later block for a domain replaces an earlier one.
  void setDomains(List<DomainBlockAst>? blocks) {
    if (blocks == null) return;
    for (final block in blocks) {
      final name = block.domain;
      domains[name] = CynefinDomain(
        name: name,
        items: block.items
            .map((item) => CynefinItem(label: item.label))
            .toList(),
      );
    }
  }

  void setTransitions(List<TransitionAst>? rawTransitions) {
    if (rawTransitions == null) return;
    transitions = rawTransitions
        .where((t) => t.from != t.to)
        .map(
          (t) => CynefinTransition(
            from: t.from,
            to: t.to,
            label: (t.label != null && t.label!.isNotEmpty) ? t.label : null,
          ),
        )
        .toList();
  }
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

CynefinModel buildCynefin(CynefinAst ast, String? title) {
  final db = CynefinDb();
  db.setDomains(ast.domains);
  db.setTransitions(ast.transitions);
  final astTitle = ast.title;
  return CynefinModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: ast.accTitle != null && ast.accTitle!.isNotEmpty
        ? ast.accTitle!.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: ast.accDescr != null && ast.accDescr!.isNotEmpty
        ? ast.accDescr!.replaceAll(_newlineSpacesRe, '\n')
        : null,
    domains: db.domains,
    transitions: db.transitions,
  );
}
