// Upstream: src/diagrams/info/model.ts

import '../../svg/root.dart';
import 'parser.dart';

class InfoModel implements RootModel {
  final String type = 'info';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;

  const InfoModel({this.title, this.accTitle, this.accDescr});
}

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

InfoModel buildInfo(InfoAst ast, String? title) {
  final astTitle = ast.title;
  return InfoModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: ast.accTitle?.replaceFirst(_leadSpacesRe, ''),
    accDescr: ast.accDescr?.replaceAll(_newlineSpacesRe, '\n'),
  );
}
