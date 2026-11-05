// Upstream: src/diagrams/packet/render.ts

import 'dart:math' as math;

import '../../preprocess.dart';
import '../../svg/builder.dart';
import '../../svg/root.dart';
import '../../svg/theme.dart';
import '../../text/entities.dart';
import '../../text/label.dart';
import '../../text/measurer.dart';
import '../../types.dart';
import '../../util/math_js.dart';
import '../common/fit_text.dart';
import '../common/fit_width.dart';
import '../common/literal_label.dart';
import 'model.dart';

Rendered renderPacket(PacketModel model, Config config, RenderOptions options) {
  return turnToFit(options, (down) => _draw(model, config, options, down));
}

Rendered _draw(
  PacketModel model,
  Config config,
  RenderOptions options,
  bool down,
) {
  final size = options.fontSize ?? 16;
  final labelSize = roundJs(size * 0.875).toDouble();
  final bitSize = roundJs(size * 0.625).toDouble();
  final measurer =
      options.measurer ??
      defaultMeasurer(options.fontFamily, options.fontFamilyMono);
  final pad = options.padding ?? 8;

  final packet = asConfig(config['packet']);
  final rowHeight = packetOption(config, 'rowHeight', 32, 1, 400);
  var bitWidth = packetOption(config, 'bitWidth', 32, 1, 400);
  final paddingX = packetOption(config, 'paddingX', 5, 0, 400);
  final paddingY = packetOption(config, 'paddingY', 5, 0, 400);
  final showBits = packet['showBits'] != false;
  final descending = packet['bitOrder'] == 'descending';
  var bitsPerRow = model.bitsPerRow;
  var rows = model.rows;
  if (down) {
    final count = math.max<int>(
      1,
      (((options.maxWidth ?? 320) - 2 * pad) / math.min(bitWidth, 18.0))
          .floor(),
    );
    // A byte is the shortest row. Below that every label is one character to a line, and a long
    // packet is a row to a bit.
    final log2Count = (math.log(count) / math.ln2).floor();
    bitsPerRow = math.min<int>(bitsPerRow, math.max<int>(8, 1 << log2Count));
    final lastRow = model.rows.isNotEmpty ? model.rows.last : null;
    final last = (lastRow != null && lastRow.isNotEmpty) ? lastRow.last.end : 0;
    if (((last + 1) / bitsPerRow).ceil() > 10000) {
      bitsPerRow = model.bitsPerRow;
    }
    bitWidth = math.min(
      bitWidth,
      math.max(18.0, ((options.maxWidth ?? 320) - 2 * pad) / bitsPerRow),
    );
    // The model has split each field at its own rows. Its pieces are joined again first, so that
    // a field is only split where one of the new rows ends. A piece counts one bit short.
    bool piece(PacketBlock block) => block.bits == block.end - block.start;
    final whole = <PacketBlock>[];
    for (final row in model.rows) {
      for (final block in row) {
        final prev = whole.isNotEmpty ? whole.last : null;
        if (prev != null &&
            piece(prev) &&
            piece(block) &&
            prev.label == block.label &&
            block.start == prev.end + 1 &&
            block.start % model.bitsPerRow == 0) {
          prev.end = block.end;
          prev.bits = prev.end - prev.start;
        } else {
          whole.add(block.copyWith());
        }
      }
    }
    rows = <List<PacketBlock>>[];
    for (final block in whole) {
      for (var start = block.start; start <= block.end;) {
        final end = math.min<int>(
          block.end,
          ((start ~/ bitsPerRow) + 1) * bitsPerRow - 1,
        );
        final index = start ~/ bitsPerRow;
        while (rows.length <= index) {
          rows.add(<PacketBlock>[]);
        }
        rows[index].add(block.copyWith(start: start, end: end));
        start = end + 1;
      }
    }
  }

  final labels = Map<PacketBlock, Label>.identity();
  if (down) {
    for (final row in rows) {
      for (final block in row) {
        final room = math.max(
          1.0,
          (block.end - block.start + 1) * bitWidth -
              math.min(paddingX, bitWidth - 1) -
              6,
        );
        final label = literalLabel(
          decodeEntities(block.label).trim(),
          measurer,
          labelSize,
          room,
        );
        labels[block] = label;
      }
    }
  }
  // Bit numbers sit above each row and need room of their own.
  final numbers = showBits ? bitSize + 4 : 0.0;
  final rowHeights = rows.map((row) {
    var height = rowHeight;
    if (down) {
      for (final block in row) {
        height = math.max(height, labels[block]!.height + 10);
      }
    }
    return height;
  }).toList();
  final tops = <double>[];
  var rowsHeight = 0.0;
  for (final height in rowHeights) {
    tops.add(rowsHeight);
    rowsHeight += numbers + height + paddingY;
  }
  if (rows.isNotEmpty) rowsHeight -= paddingY;

  final gap = math.min(paddingX, bitWidth - 1);
  final width = rows.isNotEmpty ? bitsPerRow * bitWidth - gap : 0.0;
  final title = layoutLabel(
    model.title,
    false,
    measurer,
    size,
    down ? titleRoom(options) : 4000,
    Style.Bold,
  );
  final titleHeight = title.height > 0
      ? title.height + (rowsHeight > 0 ? 12 : 0)
      : 0.0;

  // The pieces of a field split across rows share its label, so each width is fitted once.
  final fits = <String, Map<double, Fitted?>>{};
  Fitted? fit(String label, double max) {
    final byWidth = fits.putIfAbsent(label, () => <double, Fitted?>{});
    if (!byWidth.containsKey(max)) {
      byWidth[max] = fitText(
        decodeEntities(label).trim(),
        max,
        labelSize,
        roundJs(size * 0.5).toDouble(),
        measurer,
      );
    }
    return byWidth[max];
  }

  final left = pad + math.max(0.0, (title.width - width) / 2);
  final fields = StringBuffer();
  final bits = StringBuffer();
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final y = pad + tops[index] + numbers;
    final rh = rowHeights[index];
    for (final block in row) {
      final count = block.end - block.start + 1;
      final first = block.start % bitsPerRow;
      final x =
          left + (descending ? bitsPerRow - first - count : first) * bitWidth;
      final w = count * bitWidth - gap;
      final text = down ? null : fit(block.label, w - 6);
      fields
        ..write('<g class="pele-node" data-id="${block.start}-${block.end}">')
        ..write(
          '<rect x="${num(x)}" y="${num(y)}" width="${num(w)}" height="${num(rh)}" fill="var(--_s)" stroke="var(--_b)"$roundedAttr/>',
        )
        ..write(
          down
              ? labelSvg(labels[block]!, x + w / 2, y + rh / 2, '')
              : (text != null && text.size <= rh
                    ? '<text x="${num(x + w / 2)}" y="${num(y + rh / 2 + text.size * 0.35)}"${text.size == labelSize ? '' : ' font-size="${num(text.size)}"'}>${esc(text.text)}</text>'
                    : ''),
        )
        ..write('</g>');
      if (!showBits) continue;
      final leading = descending ? block.end : block.start;
      final trailing = descending ? block.start : block.end;
      if (count == 1) {
        bits.write(
          '<text x="${num(x + w / 2)}" y="${num(y - 4)}" text-anchor="middle">$leading</text>',
        );
      } else {
        bits
          ..write('<text x="${num(x)}" y="${num(y - 4)}">$leading</text>')
          ..write(
            '<text x="${num(x + w)}" y="${num(y - 4)}" text-anchor="end">$trailing</text>',
          );
      }
    }
  }

  final totalWidth = (math.max(width, title.width) + 2 * pad).ceilToDouble();
  final totalHeight = (rowsHeight + titleHeight + 2 * pad).ceilToDouble();
  final fieldsStr = fields.toString();
  final bitsStr = bits.toString();
  final content =
      (fieldsStr.isNotEmpty
          ? '<g class="pele-packet-fields" font-size="${num(labelSize)}" text-anchor="middle">$fieldsStr</g>'
          : '') +
      (bitsStr.isNotEmpty
          ? '<g class="pele-packet-bits" font-size="${num(bitSize)}" fill="var(--_m)">$bitsStr</g>'
          : '') +
      // Mermaid puts a packet's title under it.
      labelSvg(
        title,
        totalWidth / 2,
        totalHeight - pad - title.height / 2,
        ' class="pele-title" font-weight="var(--_tw)"',
      );

  return Rendered(
    svg: svgDocument(
      'packet',
      totalWidth,
      totalHeight,
      size,
      options,
      model,
      content,
    ),
    width: totalWidth,
    height: totalHeight,
    links: <LinkInfo>[],
  );
}
