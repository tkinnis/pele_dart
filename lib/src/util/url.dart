// Upstream: src/util/url.ts

import '../svg/builder.dart';
import '../text/entities.dart';
import '../types.dart';

const String _blank = 'about:blank';
final RegExp _reInvalidProtocol = RegExp(
  r'^([^\w]*)(javascript|data|vbscript)',
  caseSensitive: false,
  multiLine: true,
);
final RegExp _reHtmlEntities = RegExp(r'&#(\w+)(^\w|;)?');
final RegExp _reHtmlCtrlEntity = RegExp(
  r'&(newline|tab);',
  caseSensitive: false,
);
final RegExp _reCtrl = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u2000-\u200D\uFEFF\uD800-\uDFFF\uFFFE\uFFFF]',
  caseSensitive: false,
  multiLine: true,
  unicode: true,
);
final RegExp _reScheme = RegExp(
  r'^.+(:|&colon;)',
  caseSensitive: false,
  multiLine: true,
);
final RegExp _reWsEscape = RegExp(r'(\\|%5[cC])((%(6[eE]|72|74))|[nrt])');

String _decode(String uri) {
  try {
    return Uri.decodeComponent(uri);
  } catch (_) {
    return uri;
  }
}

String? _unwrap(String url, bool percent) {
  var out = percent ? _decode(url.trim()) : url.trim();
  var more = false;
  var rounds = 0;
  do {
    if (++rounds > 32) return null;
    out = out
        .replaceAll(_reCtrl, '')
        .replaceAllMapped(_reHtmlEntities, (m) {
          final dec = int.tryParse(m.group(1) ?? '');
          return String.fromCharCode((dec ?? 0) & 0xffff);
        })
        .replaceAll(_reHtmlCtrlEntity, '')
        .replaceAll(_reCtrl, '')
        .replaceAll(_reWsEscape, '')
        .trim();
    if (percent) out = _decode(out);
    more =
        _reCtrl.hasMatch(out) ||
        _reHtmlEntities.hasMatch(out) ||
        _reHtmlCtrlEntity.hasMatch(out) ||
        _reWsEscape.hasMatch(out);
  } while (more);
  return out;
}

String sanitizeUrl(String url) {
  if (url.isEmpty) return _blank;
  final decoded = _unwrap(url, true);
  final kept = _unwrap(url, false);
  if (decoded == null || decoded.isEmpty || kept == null || kept.isEmpty) {
    return _blank;
  }
  if (decoded.startsWith('.') || decoded.startsWith('/')) return kept;

  final scheme = _reScheme.firstMatch(decoded.trimLeft());
  if (scheme == null) return kept;

  final protocol = scheme.group(0)!.toLowerCase().trim();
  if (_reInvalidProtocol.hasMatch(protocol)) return _blank;

  final normalized = kept.trimLeft().replaceAll(r'\', '/');
  if (protocol == 'mailto:' || protocol.contains('://')) return normalized;

  if (protocol == 'http:' || protocol == 'https:') {
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || parsed.host.isEmpty) return _blank;
    var s = parsed
        .replace(
          scheme: parsed.scheme.toLowerCase(),
          host: parsed.host.toLowerCase(),
        )
        .toString();
    if (parsed.path.isEmpty &&
        !s.contains('?') &&
        !s.contains('#') &&
        !s.endsWith('/')) {
      s = '$s/';
    }
    return s;
  }
  return normalized;
}

String safeUrl(String url) {
  return sanitizeUrl(decodeEntities(url));
}

const List<String> _linkSchemes = ['http', 'https', 'mailto', 'tel'];
const List<String> _imageSchemes = ['http', 'https'];
final RegExp _reSchemeName = RegExp(
  r'^([a-z][a-z0-9+.-]*):',
  caseSensitive: false,
);
final RegExp _reNetworkPath = RegExp(r'^[\\/]{2}');

bool _allowed(String url, List<String> schemes) {
  if (_reNetworkPath.hasMatch(url)) return false;
  final scheme = _reSchemeName.firstMatch(url);
  return scheme == null || schemes.contains(scheme.group(1)!.toLowerCase());
}

String? _allow(String url, List<String> schemes) {
  final decoded = _unwrap(url, true);
  return decoded != null && _allowed(url, schemes) && _allowed(decoded, schemes)
      ? url
      : null;
}

String? linkUrl(String url, RenderOptions options) {
  return options.links == false
      ? null
      : _allow(url, options.linkSchemes ?? _linkSchemes);
}

String? imageUrl(String url, RenderOptions options) {
  return options.images == false
      ? null
      : _allow(url, options.imageSchemes ?? _imageSchemes);
}

bool internalLink(String name, RenderOptions options) {
  final url = sanitizeUrl(name);
  if (url == _blank || linkUrl(url, options) == null) return false;
  final seen = name
      .replaceAll(reInvalidXml, '')
      .replaceAll(RegExp(r'[\t\n\r]'), '')
      .replaceFirst(RegExp(r'^[\x00-\x20]+'), '');
  return linkUrl(seen, options) != null;
}

String linked(
  String body,
  String url,
  String id,
  List<LinkInfo> links,
  RenderOptions options, [
  String attrs = '',
]) {
  final href = linkUrl(url, options);
  if (href == null) return body;
  links.add(LinkInfo(id: id, href: href, internal: false));
  return '<a href="${esc(href)}"$attrs${relAttr(options)}>$body</a>';
}

String relAttr(RenderOptions options) {
  final rel = options.linkRel ?? 'noopener';
  return rel.isNotEmpty ? ' rel="${esc(rel)}"' : '';
}
