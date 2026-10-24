import 'dart:async';
import 'dart:convert';

import 'package:xml/xml_events.dart';

import '../models/channel.dart';

sealed class XmltvItem {
  const XmltvItem();
}

final class XmltvChannel extends XmltvItem {
  const XmltvChannel({
    required this.id,
    required this.displayNames,
    this.iconUrl,
  });

  final String id;
  final List<String> displayNames;
  final Uri? iconUrl;

  /// The first display name, or the id when the guide gives none.
  String get displayName => displayNames.isEmpty ? id : displayNames.first;

  @override
  String toString() => 'XmltvChannel($id, $displayNames)';
}

final class XmltvProgramme extends XmltvItem {
  const XmltvProgramme(this.programme);

  final Programme programme;

  @override
  String toString() => programme.toString();
}

/// Streaming XMLTV parser.
///
/// Guides are often hundreds of megabytes, so the document is never built in
/// memory: elements are emitted one at a time as the bytes arrive, and
/// programmes outside the optional [from]/[to] window are dropped early.
/// Decompress `.gz` files before handing the stream over.
class XmltvParser {
  const XmltvParser({this.from, this.to});

  /// Programmes ending before this instant are skipped.
  final DateTime? from;

  /// Programmes starting after this instant are skipped.
  final DateTime? to;

  Stream<XmltvItem> parseBytes(Stream<List<int>> bytes) =>
      parse(utf8.decoder.bind(bytes));

  Stream<XmltvItem> parse(Stream<String> chunks) async* {
    final b = _Builder();
    await for (final events in chunks.toXmlEvents()) {
      for (final e in events) {
        final item = b.handle(e);
        if (item != null && _inWindow(item)) yield item;
      }
    }
  }

  bool _inWindow(XmltvItem item) {
    if (item is! XmltvProgramme) return true;
    final p = item.programme;
    if (from != null && !p.stop.isAfter(from!)) return false;
    if (to != null && p.start.isAfter(to!)) return false;
    return true;
  }
}

class _Builder {
  // Channel state
  String? channelId;
  final displayNames = <String>[];
  Uri? channelIcon;

  // Programme state
  String? progChannel;
  DateTime? progStart;
  DateTime? progStop;
  String? title;
  String? desc;
  String? category;
  String? episode;
  Uri? progIcon;

  // Text capture
  String? capturing;
  final text = StringBuffer();

  XmltvItem? handle(XmlEvent e) {
    switch (e) {
      case XmlStartElementEvent(
          :final name,
          :final attributes,
          :final isSelfClosing
        ):
        String? attr(String n) {
          for (final a in attributes) {
            if (a.name == n) return a.value;
          }
          return null;
        }
        switch (name) {
          case 'channel':
            channelId = attr('id');
            displayNames.clear();
            channelIcon = null;
          case 'programme':
            progChannel = attr('channel');
            progStart = parseXmltvTime(attr('start'));
            progStop = parseXmltvTime(attr('stop'));
            title = desc = category = episode = null;
            progIcon = null;
          case 'icon':
            final src = Uri.tryParse(attr('src') ?? '');
            if (progChannel != null) {
              progIcon ??= src;
            } else if (channelId != null) {
              channelIcon ??= src;
            }
          case 'display-name' ||
                  'title' ||
                  'desc' ||
                  'category' ||
                  'episode-num'
              when !isSelfClosing:
            // Keep the first of each; additional languages are ignored.
            capturing = name;
            text.clear();
        }
      case XmlTextEvent(:final value) when capturing != null:
        text.write(value);
      case XmlCDATAEvent(:final value) when capturing != null:
        text.write(value);
      case XmlEndElementEvent(:final name):
        if (name == capturing) {
          final v = text.toString().trim();
          switch (name) {
            case 'display-name' when channelId != null && progChannel == null:
              if (v.isNotEmpty) displayNames.add(v);
            case 'title':
              title ??= v;
            case 'desc':
              desc ??= v;
            case 'category':
              category ??= v;
            case 'episode-num':
              episode ??= v;
          }
          capturing = null;
        }
        if (name == 'channel' && channelId != null) {
          final item = XmltvChannel(
            id: channelId!,
            displayNames: List.unmodifiable(displayNames),
            iconUrl: channelIcon,
          );
          channelId = null;
          return item;
        }
        if (name == 'programme') {
          final ch = progChannel, start = progStart, stop = progStop;
          progChannel = null;
          if (ch == null || start == null) return null;
          return XmltvProgramme(Programme(
            channelId: ch,
            start: start,
            // A missing stop is legal; the importer can fix it up from the
            // next programme. Default to one hour.
            stop: stop ?? start.add(const Duration(hours: 1)),
            title: title ?? '',
            description: (desc?.isEmpty ?? true) ? null : desc,
            category: category,
            episode: episode,
            iconUrl: progIcon,
          ));
        }
      default:
        break;
    }
    return null;
  }
}

/// Parses XMLTV timestamps (`YYYYMMDDhhmmss +hhmm`) into UTC.
///
/// Seconds and the offset are optional; without an offset the time is UTC,
/// as the XMLTV DTD specifies.
DateTime? parseXmltvTime(String? raw) {
  if (raw == null) return null;
  final m = RegExp(
          r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{2}:?\d{2})?')
      .firstMatch(raw.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i)!);
  final base =
      DateTime.utc(g(1), g(2), g(3), g(4), g(5), m.group(6) == null ? 0 : g(6));
  final off = m.group(7);
  if (off == null) return base;
  final digits = off.replaceAll(':', '');
  final sign = digits.startsWith('-') ? -1 : 1;
  final minutes = int.parse(digits.substring(1, 3)) * 60 +
      int.parse(digits.substring(3, 5));
  return base.subtract(Duration(minutes: sign * minutes));
}
