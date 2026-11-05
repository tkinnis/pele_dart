// Upstream: src/diagrams/packet/model.ts

import 'dart:math' as math;

import '../../errors.dart';
import '../../preprocess.dart';
import '../../svg/root.dart';
import 'parser.dart';

class PacketBlock {
  int start;
  int end;
  // As Mermaid counts it: one less than the width for the pieces of a field split across rows.
  int bits;
  String label;

  PacketBlock({
    required this.start,
    required this.end,
    required this.bits,
    required this.label,
  });

  PacketBlock copyWith({int? start, int? end, int? bits, String? label}) =>
      PacketBlock(
        start: start ?? this.start,
        end: end ?? this.end,
        bits: bits ?? this.bits,
        label: label ?? this.label,
      );
}

class PacketModel implements RootModel {
  final String type = 'packet';
  final String? title;
  @override
  final String? accTitle;
  @override
  final String? accDescr;
  final int bitsPerRow;
  final List<List<PacketBlock>> rows;

  const PacketModel({
    required this.title,
    required this.accTitle,
    required this.accDescr,
    required this.bitsPerRow,
    required this.rows,
  });
}

const int _maxRows = 10000;

final RegExp _leadSpacesRe = RegExp(r'^\s+');
final RegExp _newlineSpacesRe = RegExp(r'\n\s+');

double packetOption(
  Config config,
  String key,
  double fallback,
  double min,
  double max,
) {
  final packet = config['packet'];
  final value = packet is Map ? packet[key] : null;
  if (value is int && value >= min) {
    return math.min(value.toDouble(), max);
  }
  if (value is double && !value.isNaN && value >= min) {
    return math.min(value, max);
  }
  return fallback;
}

PeleError _invalid(String message) {
  return PeleError(message, 'semantic', const PeleErrorInfo(type: 'packet'));
}

PacketModel buildPacket(PacketAst ast, Config config, String? title) {
  final bitsPerRow = packetOption(config, 'bitsPerRow', 32, 1, 4096).floor();
  final rows = <List<PacketBlock>>[];
  var lastBit = -1;
  var word = <PacketBlock>[];
  var row = 1;

  for (final block in ast.blocks) {
    var start = block.start;
    var end = block.end;
    var bits = block.bits;
    if (start != null && end != null && end < start) {
      throw _invalid(
        'Packet block $start - $end is invalid. End must be greater than start.',
      );
    }
    start ??= lastBit + 1;
    if (start != lastBit + 1) {
      throw _invalid(
        'Packet block $start - ${end ?? start} is not contiguous. It should start from ${lastBit + 1}.',
      );
    }
    if (bits == 0) {
      throw _invalid(
        'Packet block $start is invalid. Cannot have a zero bit field.',
      );
    }
    end ??= start + (bits ?? 1) - 1;
    bits ??= end - start + 1;
    lastBit = end;

    while (word.length <= bitsPerRow + 1 && rows.length < _maxRows) {
      final rowEnd = row * bitsPerRow - 1;
      if (end <= rowEnd) {
        word.add(
          PacketBlock(start: start!, end: end, bits: bits!, label: block.label),
        );
        if (end == rowEnd) {
          rows.add(word);
          word = <PacketBlock>[];
          row++;
        }
        break;
      }
      word.add(
        PacketBlock(
          start: start!,
          end: rowEnd,
          bits: rowEnd - start,
          label: block.label,
        ),
      );
      rows.add(word);
      word = <PacketBlock>[];
      row++;
      start = rowEnd + 1;
      bits = end - start;
    }
  }
  if (word.isNotEmpty) rows.add(word);

  final astTitle = ast.title;
  final astAccTitle = ast.accTitle;
  final astAccDescr = ast.accDescr;
  return PacketModel(
    title: (astTitle != null && astTitle.isNotEmpty) ? astTitle : title,
    accTitle: (astAccTitle != null && astAccTitle.isNotEmpty)
        ? astAccTitle.replaceFirst(_leadSpacesRe, '')
        : null,
    accDescr: (astAccDescr != null && astAccDescr.isNotEmpty)
        ? astAccDescr.replaceAll(_newlineSpacesRe, '\n')
        : null,
    bitsPerRow: bitsPerRow,
    rows: rows,
  );
}
