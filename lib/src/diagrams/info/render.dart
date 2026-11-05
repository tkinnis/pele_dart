// Upstream: src/diagrams/info/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import 'model.dart';

const String _version = '1.13.0';

Rendered renderInfo(InfoModel model, Config config, RenderOptions options) {
  final size = options.fontSize ?? 16;
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    4000,
    Style.bold,
  );
  final titleHeight = title.height > 0 ? title.height + 8 : 0.0;
  final text = layoutLabel('Pele v$_version', false, measurer, size, 4000);

  final width = (math.max(title.width, text.width) + 2 * pad).ceilToDouble();
  final height = (titleHeight + text.height + 2 * pad).ceilToDouble();
  final content =
      labelSvg(
        title,
        width / 2,
        pad + title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      ) +
      labelSvg(
        text,
        width / 2,
        pad + titleHeight + text.height / 2,
        ' class="pele-version" fill="var(--_m)"',
      );

  return Rendered(
    svg: svgDocument('info', width, height, size, options, model, content),
    width: width,
    height: height,
    links: <LinkInfo>[],
  );
}
