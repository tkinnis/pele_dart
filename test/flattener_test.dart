import 'package:pele_dart/pele_dart.dart';
import 'package:test/test.dart';

void main() {
  group('flattenPeleSvg — Pass 1: CSS Variables, color-mix, and calc', () {
    test('resolves light, dark, and custom PelePalette variables', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" '
          'style="--_bg:var(--pele-bg);--_fg:var(--pele-fg);font:16px sans-serif" '
          'fill="var(--_fg)">'
          '<rect fill="var(--_s)" stroke="var(--_b)" '
          'style="rx:var(--_r);stroke-width:var(--pele-stroke-width);"/>'
          '<path stroke="var(--_l)" fill="var(--_c)"/>'
          '<text fill="var(--_m)" font-weight="var(--_w)" font-family="var(--_fm)">mono</text>'
          '<circle fill="var(--pele-c0)" stroke="var(--pele-series-2)"/>'
          '<polygon fill="var(--pele-critical)" stroke="var(--pele-code)"/>'
          '</svg>';

      final lightOut = flattenPeleSvg(svg, palette: PelePalette.light);
      expect(lightOut, isNot(contains('var(--')));
      expect(lightOut, contains('fill="#24292e"'));
      expect(lightOut, contains('rx="6"'));
      expect(lightOut, contains('font-weight="bold"'));
      expect(lightOut, contains('font-family="Menlo"'));
      expect(lightOut, contains('fill="#4c78a8"'));
      expect(lightOut, contains('stroke="#f58518"'));
      expect(lightOut, contains('fill="#e45756"'));

      final darkOut = flattenPeleSvg(svg, palette: PelePalette.dark);
      expect(darkOut, isNot(contains('var(--')));
      expect(darkOut, contains('fill="#e1e4e8"'));
      expect(darkOut, contains('fill="#f87171"'));

      const customPalette = PelePalette(
        bg: '#101010',
        fg: '#f0f0f0',
        fgOnLight: '#111111',
        fgOnDark: '#eeeeee',
        muted: '#888888',
        line: '#cccccc',
        surface: '#202020',
        surfaceAlt: '#303030',
        border: '#404040',
        accent: '#00aaff',
        code: '#252525',
        critical: '#ff3333',
        radius: 10,
        strokeWidth: 2,
        thickStrokeWidth: 3.5,
        hairlineStrokeWidth: 0.75,
        fontFamily: '"Inter", sans-serif',
        monoFontFamily: '"JetBrains Mono", monospace',
        colors: <String>['#123456', '#654321'],
      );
      const customSvg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" '
          'style="font:14px sans-serif">'
          '<rect fill="var(--pele-fg-on-light)" stroke="var(--pele-fg-on-dark)" '
          'style="rx:var(--_r);stroke-width:var(--pele-thick-stroke-width);"/>'
          '<line stroke-width="var(--pele-hairline-stroke-width)" stroke="var(--pele-series-1)"/>'
          '<text font-family="var(--pele-font)">custom</text>'
          '<text font-family="var(--pele-font-mono)">code</text>'
          '</svg>';
      final customOut = flattenPeleSvg(customSvg, palette: customPalette);
      expect(customOut, isNot(contains('var(--')));
      expect(customOut, contains('font-family="Inter" font-size="14"'));
      expect(customOut, contains('fill="#111111" stroke="#eeeeee"'));
      expect(customOut, contains('rx="10"'));
      expect(customOut, contains('stroke-width="3.5"'));
      expect(customOut, contains('stroke-width="0.75" stroke="#123456"'));
      expect(customOut, contains('font-family="JetBrains Mono"'));
    });

    test('extracts root <svg> --pele-series-N overrides and resolves nested fallbacks', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" '
          'style="--pele-series-1:#ff00aa;--pele-series-2:#00ffaa;font:16px sans-serif">'
          '<rect fill="var(--pele-series-1,#4c78a8)" stroke="var(--pele-series-2,#f58518)"/>'
          '<rect fill="var(--nonexistent-var, #abcdef)" stroke="var(--missing-outer, var(--_c))"/>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, contains('fill="#ff00aa" stroke="#00ffaa"'));
      expect(flat, contains('fill="#abcdef" stroke="#5b7bd5"'));
    });

    test('evaluates color-mix(in srgb, ...) across all percentage, hex, rgb, and named color forms', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          // Both percentages summing to 100%
          '<rect id="r1" fill="color-mix(in srgb, #ff0000 25%, #0000ff 75%)"/>'
          // Both percentages not summing to 100% (normalized 1:3)
          '<rect id="r2" fill="color-mix(in srgb, #ff0000 10%, #0000ff 30%)"/>'
          // First percentage only
          '<rect id="r3" fill="color-mix(in srgb, #00ff00 50%, #000000)"/>'
          // Second percentage only
          '<rect id="r4" fill="color-mix(in srgb, #00ff00, #000000 50%)"/>'
          // Neither percentage (defaults to 50/50)
          '<rect id="r5" fill="color-mix(in srgb, white, black)"/>'
          // 3-digit hex & rgb(...)
          '<rect id="r6" fill="color-mix(in srgb, #f00 50%, rgb(0, 0, 255))"/>'
          // Unparseable color-mix left intact without crashing
          '<rect id="r7" fill="color-mix(in srgb, unknownColor 50%, #fff)"/>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, contains('id="r1" fill="#4000bf"'));
      expect(flat, contains('id="r2" fill="#4000bf"'));
      expect(flat, contains('id="r3" fill="#008000"'));
      expect(flat, contains('id="r4" fill="#008000"'));
      expect(flat, contains('id="r5" fill="#808080"'));
      expect(flat, contains('id="r6" fill="#800080"'));
      expect(
        flat,
        contains('id="r7" fill="color-mix(in srgb, unknownColor 50%, #fff)"'),
      );
    });

    test('evaluates calc(A + B) with px and signed numbers', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          '<rect rx="calc(4px + 2px)" ry="calc(10 + -3.5)"/>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, contains('rx="6" ry="6.5"'));
    });
  });

  group('flattenPeleSvg — Pass 2 & 3: currentColor and baseline-shift', () {
    test('replaces currentColor with palette.fg and converts unpositioned baseline-shift', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          '<path stroke="currentColor" fill="none"/>'
          '<text><tspan baseline-shift="sub" font-size="smaller">i</tspan>'
          '<tspan baseline-shift="super" font-size="smaller">2</tspan></text>'
          '</svg>';
      final flat = flattenPeleSvg(svg, palette: PelePalette.light);
      expect(flat, isNot(contains('currentColor')));
      expect(flat, contains('stroke="#24292e"'));
      expect(flat, contains('<tspan dy="3" font-size="10">i</tspan>'));
      expect(flat, contains('<tspan dy="-4" font-size="10">2</tspan>'));
    });
  });

  group('flattenPeleSvg — Pass 4 & 5: Inline style promotion and SVG 2 gradient fallback', () {
    test('promotes style properties, strips px units, resolves color to fill on text/tspan/g, and preserves unknown styles', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele pele-flowchart" '
          'style="max-width:100%;font:15px sans-serif;--custom:123">'
          '<g style="color:#123456;font-size:13px">'
          '<rect x="0" y="0" width="20" height="20" rx="2" '
          'style="rx:8px;ry:4px;fill:#abcdef;stroke:#112233;stroke-width:2.5px;'
          'stroke-dasharray:4,2;stroke-dashoffset:1;stroke-linecap:round;'
          'stroke-linejoin:bevel;fill-opacity:0.8;stroke-opacity:0.9;opacity:0.95;'
          'pointer-events:none"/>'
          '<text style="color:#654321;font-family:-apple-system,BlinkMacSystemFont,\'Helvetica Neue\',sans-serif;'
          'font-size:14px;font-weight:bold;font-style:italic;text-decoration:underline">styled</text>'
          '<tspan style="color:#998877;font-family:ui-monospace,Menlo,monospace">code</tspan>'
          '</g>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, contains('font-family="Helvetica" font-size="15"'));
      expect(flat, contains('<g font-size="13" fill="#123456">'));
      expect(flat, contains('rx="8"'));
      expect(flat, contains('ry="4"'));
      expect(flat, contains('fill="#abcdef"'));
      expect(flat, contains('stroke="#112233"'));
      expect(flat, contains('stroke-width="2.5"'));
      expect(flat, contains('stroke-dasharray="4,2"'));
      expect(flat, contains('stroke-dashoffset="1"'));
      expect(flat, contains('stroke-linecap="round"'));
      expect(flat, contains('stroke-linejoin="bevel"'));
      expect(flat, contains('fill-opacity="0.8"'));
      expect(flat, contains('stroke-opacity="0.9"'));
      expect(flat, contains('opacity="0.95"'));
      expect(flat, contains('style="pointer-events:none;"'));
      expect(flat, contains('fill="#654321"'));
      expect(flat, contains('font-family="Helvetica Neue"'));
      expect(flat, contains('font-size="14"'));
      expect(flat, contains('font-weight="bold"'));
      expect(flat, contains('font-style="italic"'));
      expect(flat, contains('text-decoration="underline"'));
      expect(flat, contains('font-family="Menlo" fill="#998877"'));
    });

    test('strips SVG 2 fallback color after paint server url(#id) fill', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          '<path d="M0,0L10,10" fill="url(#sankey-grad-0) #4c78a8"/>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, contains('fill="url(#sankey-grad-0)"'));
      expect(flat, isNot(contains('#4c78a8')));
    });
  });

  group('flattenPeleSvg — Pass 6: Nested <svg class="pele-icon|pele-math"> flattening', () {
    test('converts nested icon and math SVGs with uniform scale, non-uniform scale, and viewBox offset', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          // Uniform scale + zero viewBox origin
          '<svg class="pele-icon" data-icon="cloud" x="10" y="20" width="12" height="12" viewBox="0 0 24 24" overflow="visible"><path d="M1,1"/></svg>'
          // Non-uniform scale + non-zero viewBox origin
          '<svg class="pele-math" x="5" y="15" width="40" height="20" viewBox="-10 -5 20 20"><path d="M0,0"/></svg>'
          // 1:1 scale at (0, 0)
          '<svg class="pele-icon" x="0" y="0" width="24" height="24" viewBox="0 0 24 24"><circle cx="12" cy="12" r="5"/></svg>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, isNot(contains('<svg class="pele-icon"')));
      expect(flat, isNot(contains('<svg class="pele-math"')));
      expect(flat, isNot(contains('overflow="visible"')));
      expect(
        flat,
        contains(
          '<g class="pele-icon" data-icon="cloud" transform="translate(10,20) scale(0.5)"><path d="M1,1"/></g>',
        ),
      );
      expect(
        flat,
        contains(
          '<g class="pele-math" transform="translate(5,15) scale(2,1) translate(10,5)"><path d="M0,0"/></g>',
        ),
      );
      expect(
        flat,
        contains('<g class="pele-icon"><circle cx="12" cy="12" r="5"/></g>'),
      );
    });
  });

  group('flattenPeleSvg — Pass 7: Group opacity and font-size propagation', () {
    test('multiplies nested group fill-opacity and stroke-opacity and skips fill="none" / stroke="none"', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          '<g fill-opacity="0.5" stroke-opacity="0.8" font-size="14">'
          '<path id="p1" d="M0,0L1,1" fill="#ff0000" stroke="#00ff00"/>'
          '<path id="p2" d="M0,0L1,1" fill="none" stroke="none"/>'
          '<g fill-opacity="0.5" stroke-opacity="0.5" font-size="11">'
          '<rect id="r1" x="0" y="0" width="10" height="10" fill-opacity="0.4" stroke-opacity="0.5"/>'
          '<text id="t1" x="0" y="0">inherits 11</text>'
          '<text id="t2" x="0" y="0" font-size="9">keeps 9</text>'
          '</g>'
          '<text id="t3" x="0" y="0">inherits 14</text>'
          '</g>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(
        flat,
        contains(
          '<path id="p1" d="M0,0L1,1" fill="#ff0000" stroke="#00ff00" fill-opacity="0.5" stroke-opacity="0.8"/>',
        ),
      );
      expect(
        flat,
        contains('<path id="p2" d="M0,0L1,1" fill="none" stroke="none"/>'),
      );
      // 0.5 * 0.5 * 0.4 = 0.1 for fill-opacity; 0.8 * 0.5 * 0.5 = 0.2 for stroke-opacity
      expect(
        flat,
        contains(
          '<rect id="r1" x="0" y="0" width="10" height="10" fill-opacity="0.1" stroke-opacity="0.2"/>',
        ),
      );
      expect(
        flat,
        contains(
          '<text id="t1" x="0" y="0" font-size="11" fill-opacity="0.25" stroke-opacity="0.4">inherits 11</text>',
        ),
      );
      expect(
        flat,
        contains(
          '<text id="t2" x="0" y="0" font-size="9" fill-opacity="0.25" stroke-opacity="0.4">keeps 9</text>',
        ),
      );
      expect(
        flat,
        contains(
          '<text id="t3" x="0" y="0" font-size="14" fill-opacity="0.5" stroke-opacity="0.8">inherits 14</text>',
        ),
      );
    });
  });

  group('flattenPeleSvg — Pass 8: Multi-<tspan> coordinate & baseline normalization', () {
    test('promotes first <tspan> x and y onto <text> when <text> lacks x or y', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          '<g transform="translate(263.75, 19.5)">'
          '<text class="pele-label" text-anchor="middle" xml:space="preserve">'
          '<tspan x="92.25" y="21.6" font-weight="bold">Pele</tspan>'
          '<tspan> is the</tspan>'
          '<tspan x="92.25" y="42.6">goddess of volcanoes</tspan>'
          '</text>'
          '</g>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(
        flat,
        contains(
          '<text class="pele-label" text-anchor="middle" xml:space="preserve" x="92.25" y="21.6">'
          '<tspan x="92.25" y="21.6" font-weight="bold">Pele</tspan>'
          '<tspan> is the</tspan>'
          '<tspan x="92.25" y="42.6">goddess of volcanoes</tspan>'
          '</text>',
        ),
      );
    });

    test('preserves <text> unchanged when <text> already has x and y and no dy is present', () {
      const sankeyLabel =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          '<g font-size="12">'
          '<text x="568" y="49.79" text-anchor="end">Over generation / exports '
          '<tspan class="pele-sankey-value" fill="#636669">104.45</tspan></text>'
          '</g>'
          '</svg>';
      final flat = flattenPeleSvg(sankeyLabel);
      expect(
        flat,
        contains(
          '<text x="568" y="49.79" text-anchor="end" font-size="12">'
          'Over generation / exports '
          '<tspan class="pele-sankey-value" fill="#636669">104.45</tspan></text>',
        ),
      );
    });

    test('expands subscript and superscript dy spans into explicit x and y coordinates across start, middle, and end anchors', () {
      const svg =
          '<svg xmlns="http://www.w3.org/2000/svg" class="pele" style="font:16px sans-serif">'
          // 1. text-anchor="start" on <text x="10" y="30"> with mixed raw text and sub/sup tspans
          '<text id="start-sub" x="10" y="30" text-anchor="start">'
          'H<tspan baseline-shift="sub" font-size="smaller">2</tspan>O'
          '<tspan baseline-shift="super" font-size="smaller">+</tspan>'
          '</text>'
          // 2. text-anchor="middle" with multi-line <tspan x="..." y="..."> and bold/mono styles
          '<text id="mid-sub" text-anchor="middle">'
          '<tspan x="100" y="50" font-weight="bold">x</tspan>'
          '<tspan baseline-shift="sub" font-size="smaller">1</tspan>'
          '<tspan x="100" y="70" font-family="Menlo">y</tspan>'
          '<tspan baseline-shift="super" font-size="smaller">2</tspan>'
          '</text>'
          // 3. text-anchor="end" with HTML entities
          '<text id="end-sub" x="200" y="90" text-anchor="end">'
          '<tspan>&alpha;</tspan>'
          '<tspan baseline-shift="sub" font-size="smaller">0</tspan>'
          '</text>'
          '</svg>';
      final flat = flattenPeleSvg(svg);
      expect(flat, isNot(contains('dy="3"')));
      expect(flat, isNot(contains('dy="-4"')));

      // Verify start-anchored H2O+ coordinates
      final wH = metricsMeasurer.width('H', 16);
      final w2 = metricsMeasurer.width('2', 10);
      final wO = metricsMeasurer.width('O', 16);
      expect(
        flat,
        contains(
          '<text x="10" y="30" id="start-sub" text-anchor="start">'
          '<tspan x="10" y="30">H</tspan>'
          '<tspan x="${(10 + wH).toStringAsFixed(2).replaceAll(RegExp(r"\.?0+$"), "")}" y="33" font-size="10">2</tspan>'
          '<tspan x="${(10 + wH + w2).toStringAsFixed(2).replaceAll(RegExp(r"\.?0+$"), "")}" y="30">O</tspan>'
          '<tspan x="${(10 + wH + w2 + wO).toStringAsFixed(2).replaceAll(RegExp(r"\.?0+$"), "")}" y="26" font-size="10">+</tspan>'
          '</text>',
        ),
      );

      // Verify middle-anchored multi-line x_1 / y^2 baselines (50, 53 and 70, 66)
      expect(flat, contains('id="mid-sub" text-anchor="start"'));
      expect(flat, contains('y="50" font-weight="bold">x</tspan>'));
      expect(flat, contains('y="53" font-size="10">1</tspan>'));
      expect(flat, contains('y="70" font-family="Menlo">y</tspan>'));
      expect(flat, contains('y="66" font-size="10">2</tspan>'));

      // Verify end-anchored entity-decoded alpha_0
      final wAlpha = metricsMeasurer.width('α', 16);
      final w0 = metricsMeasurer.width('0', 10);
      final expectedEndStart = 200.0 - (wAlpha + w0);
      expect(
        flat,
        contains(
          '<text x="200" y="90" id="end-sub" text-anchor="start">'
          '<tspan x="${expectedEndStart.toStringAsFixed(2).replaceAll(RegExp(r"\.?0+$"), "")}" y="90">&alpha;</tspan>',
        ),
      );
    });
  });
}
