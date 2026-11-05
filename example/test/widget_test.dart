import 'package:flutter_test/flutter_test.dart';
import 'package:pele_dart/pele_dart.dart';
import 'package:pele_dart_comparison_demo/gallery_samples.dart';
import 'package:pele_dart_comparison_demo/svg_diff_view.dart';

void main() {
  test('Gallery contains all 33 Mermaid diagram families', () {
    expect(gallerySamples.length, 33);
    final ids = gallerySamples.map((s) => s.id).toSet();
    expect(ids.length, 33);
  });

  test('prettyPrintSvg formats compact SVG into indented multi-line XML', () {
    final svg = renderMermaid('info\n  showInfo');
    final formatted = prettyPrintSvg(svg);
    expect(formatted, contains('<svg'));
    expect(formatted.split('\n').length, greaterThan(3));
  });
}
