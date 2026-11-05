// Upstream: src/diagrams/pie/model.ts

import '../../errors.dart';
import '../../svg/root.dart';
import 'parser.dart';

class PieModel implements RootModel {
  final String type = 'pie';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  final bool showData;
  final Map<String, double> sections;

  const PieModel({
    this.title,
    this.accTitle,
    this.accDescr,
    required this.showData,
    required this.sections,
  });
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

String _fmtValue(double v) =>
    v == 0 ? '0' : (v == v.truncateToDouble() ? '${v.toInt()}' : '$v');

PieModel buildPie(PieAst ast, String? title) {
  final sections = <String, double>{};
  for (final section in ast.sections) {
    final label = section.label;
    final value = section.value;
    if (value < 0) {
      throw PeleError(
        '"$label" has invalid value: ${_fmtValue(value)}. Negative values are not allowed in pie charts. All slice values must be >= 0.',
        'semantic',
        const PeleErrorInfo(type: 'pie'),
      );
    }
    if (!sections.containsKey(label)) {
      sections[label] = value;
    }
  }
  final astTitle = ast.title;
  final astAccTitle = ast.accTitle;
  final astAccDescr = ast.accDescr;
  return PieModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: (astAccTitle != null && astAccTitle.isNotEmpty)
        ? astAccTitle.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: (astAccDescr != null && astAccDescr.isNotEmpty)
        ? astAccDescr.replaceAll(_newlineSpacesRe, '\n')
        : null,
    showData: ast.showData,
    sections: sections,
  );
}
