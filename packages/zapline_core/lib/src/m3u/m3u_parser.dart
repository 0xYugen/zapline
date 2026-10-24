import 'dart:async';
import 'dart:convert';

/// Playlist-level attributes from the `#EXTM3U` header line.
class M3uHeader {
  const M3uHeader(this.attributes);

  final Map<String, String> attributes;

  /// XMLTV guide URLs declared via `url-tvg` / `x-tvg-url` (comma separated).
  List<Uri> get epgUrls {
    final raw = attributes['url-tvg'] ?? attributes['x-tvg-url'];
    if (raw == null) return const [];
    return [
      for (final part in raw.split(','))
        if (Uri.tryParse(part.trim()) case final uri?
            when part.trim().isNotEmpty)
          uri,
    ];
  }
}

/// One `#EXTINF` entry plus its stream URL.
class M3uEntry {
  const M3uEntry({
    required this.title,
    required this.url,
    required this.duration,
    this.attributes = const {},
    this.group,
    this.httpHeaders = const {},
    this.kodiProps = const {},
  });

  final String title;
  final String url;
  final int duration;
  final Map<String, String> attributes;

  /// `group-title`, falling back to a preceding `#EXTGRP` line.
  final String? group;
  final Map<String, String> httpHeaders;
  final Map<String, String> kodiProps;

  String? get tvgId => _nonEmpty(attributes['tvg-id']);
  String? get tvgName => _nonEmpty(attributes['tvg-name']);
  String? get tvgLogo => _nonEmpty(attributes['tvg-logo']);
  int? get tvgChno => int.tryParse(attributes['tvg-chno'] ?? '');
  String? get catchup => _nonEmpty(attributes['catchup']);
  String? get catchupSource => _nonEmpty(attributes['catchup-source']);
  int? get catchupDays => int.tryParse(attributes['catchup-days'] ?? '');

  static String? _nonEmpty(String? s) => (s == null || s.isEmpty) ? null : s;
}

/// Streaming, allocation-light M3U/M3U8 parser.
///
/// Tolerates missing headers, CRLF line endings, a UTF-8 BOM, blank lines
/// and comma characters inside quoted attribute values.
class M3uParser {
  M3uParser();

  static final _attr = RegExp(r'([A-Za-z0-9_-]+)="([^"]*)"');

  M3uHeader _header = const M3uHeader({});

  /// Header attributes; populated once the `#EXTM3U` line has been read.
  M3uHeader get header => _header;

  /// Parses a whole playlist held in memory.
  List<M3uEntry> parse(String content) {
    final out = <M3uEntry>[];
    final state = _EntryState();
    for (final line in const LineSplitter().convert(content)) {
      final entry = _consume(line, state);
      if (entry != null) out.add(entry);
    }
    return out;
  }

  /// Parses a playlist from a stream of lines (use with large remote files).
  Stream<M3uEntry> parseLines(Stream<String> lines) async* {
    final state = _EntryState();
    await for (final line in lines) {
      final entry = _consume(line, state);
      if (entry != null) yield entry;
    }
  }

  /// Convenience for byte streams such as an HTTP response body.
  Stream<M3uEntry> parseBytes(Stream<List<int>> bytes) =>
      parseLines(const LineSplitter().bind(utf8.decoder.bind(bytes)));

  M3uEntry? _consume(String rawLine, _EntryState s) {
    var line = rawLine.trim();
    if (line.isEmpty) return null;
    if (line.codeUnitAt(0) == 0xFEFF) line = line.substring(1);

    if (line.startsWith('#EXTM3U')) {
      _header = M3uHeader(_parseAttributes(line));
      return null;
    }
    if (line.startsWith('#EXTINF:')) {
      s.reset();
      final body = line.substring(8);
      final commaIdx = _titleComma(body);
      final meta = commaIdx < 0 ? body : body.substring(0, commaIdx);
      s.title = commaIdx < 0 ? '' : body.substring(commaIdx + 1).trim();
      s.attributes = _parseAttributes(meta);
      s.duration = int.tryParse(meta.split(RegExp(r'\s')).first) ?? -1;
      s.open = true;
      return null;
    }
    if (line.startsWith('#EXTGRP:')) {
      s.extGroup = line.substring(8).trim();
      return null;
    }
    if (line.startsWith('#EXTVLCOPT:')) {
      final kv = _splitKv(line.substring(11));
      if (kv != null) {
        switch (kv.$1.toLowerCase()) {
          case 'http-user-agent':
            s.headers['User-Agent'] = kv.$2;
          case 'http-referrer' || 'http-referer':
            s.headers['Referer'] = kv.$2;
          case 'http-origin':
            s.headers['Origin'] = kv.$2;
        }
      }
      return null;
    }
    if (line.startsWith('#KODIPROP:')) {
      final kv = _splitKv(line.substring(10));
      if (kv != null) s.kodiProps[kv.$1] = kv.$2;
      return null;
    }
    if (line.startsWith('#')) return null;

    // A URL line. Entries without #EXTINF are still accepted (bare lists).
    final attrs = s.open ? s.attributes : const <String, String>{};
    final title =
        s.open && s.title.isNotEmpty ? s.title : (attrs['tvg-name'] ?? line);
    final group = attrs['group-title'];
    final entry = M3uEntry(
      title: title,
      url: line,
      duration: s.open ? s.duration : -1,
      attributes: attrs,
      group: (group != null && group.isNotEmpty) ? group : s.extGroup,
      httpHeaders: Map.unmodifiable(s.headers),
      kodiProps: Map.unmodifiable(s.kodiProps),
    );
    s.reset();
    return entry;
  }

  /// Index of the comma separating metadata from the title, ignoring commas
  /// inside quoted attribute values.
  static int _titleComma(String body) {
    var inQuotes = false;
    for (var i = 0; i < body.length; i++) {
      final c = body.codeUnitAt(i);
      if (c == 0x22) {
        inQuotes = !inQuotes;
      } else if (c == 0x2C && !inQuotes) {
        return i;
      }
    }
    return -1;
  }

  static Map<String, String> _parseAttributes(String s) => {
        for (final m in _attr.allMatches(s))
          m.group(1)!.toLowerCase(): m.group(2)!,
      };

  static (String, String)? _splitKv(String s) {
    final i = s.indexOf('=');
    if (i <= 0) return null;
    return (s.substring(0, i).trim(), s.substring(i + 1).trim());
  }
}

class _EntryState {
  bool open = false;
  String title = '';
  int duration = -1;
  Map<String, String> attributes = const {};
  String? extGroup;
  Map<String, String> headers = {};
  Map<String, String> kodiProps = {};

  void reset() {
    open = false;
    title = '';
    duration = -1;
    attributes = const {};
    headers = {};
    kodiProps = {};
    // extGroup is kept on purpose: as in Kodi pvr.iptvsimple, #EXTGRP
    // applies to all following entries until another #EXTGRP appears.
  }
}
