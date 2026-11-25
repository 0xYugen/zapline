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
  const XmltvParser({this.from, this.to, this.onComplete});

  /// Programmes ending before this instant are skipped.
  final DateTime? from;

  /// Programmes starting after this instant are skipped.
  final DateTime? to;

  /// Called when the document's closing `</tv>` has been read: the guide
  /// arrived whole, not cut short somewhere.
  final void Function()? onComplete;

  Stream<XmltvItem> parseBytes(Stream<List<int>> bytes) =>
      // A stray byte that isn't UTF-8 (some free guides have a few) must
      // not lose the whole guide.
      parse(const Utf8Decoder(allowMalformed: true).bind(bytes));

  Stream<XmltvItem> parse(Stream<String> chunks) async* {
    final b = _Builder(from, to);
    var whole = false;
    await for (final events in chunks.toXmlEvents()) {
      for (final e in events) {
        if (e is XmlEndElementEvent && e.name == 'tv') whole = true;
        final item = b.handle(e);
        if (item != null) yield item;
      }
    }
    if (whole) onComplete?.call();
  }
}

class _Builder {
  _Builder(this.from, this.to);

  /// The window: a programme outside it is told apart by its times, at its
  /// start tag, and nothing else of it is read.
  final DateTime? from;
  final DateTime? to;

  /// Inside a programme outside the window.
  bool skipping = false;

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
            final start = progStart =
                parseXmltvTime(attr('start'), channelId: progChannel);
            final stop =
                progStop = parseXmltvTime(attr('stop'), channelId: progChannel);
            title = desc = category = episode = null;
            progIcon = null;
            // A missing stop counts as an hour (see the end tag).
            final end = stop ?? start?.add(const Duration(hours: 1));
            skipping = progChannel == null ||
                start == null ||
                (from != null && !end!.isAfter(from!)) ||
                (to != null && start.isAfter(to!));
          case _ when skipping:
            break;
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
          if (skipping) {
            skipping = false;
            return null;
          }
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
///
/// With the guide [channelId], a local time whose offset is the wrong one
/// of its European country's pair is fixed: guides are often left on
/// summer time after the clocks change (`+0200` for Italy in November),
/// which puts every programme an hour off. See [fixEuropeanOffset].
DateTime? parseXmltvTime(String? raw, {String? channelId}) {
  if (raw == null) return null;
  // Read by hand: two per programme, a million programmes in a big guide.
  final s = raw.trim();
  // The number in s[at, at + n), or -1 when it isn't all ASCII digits.
  int digits(int at, int n) {
    if (at + n > s.length) return -1;
    var v = 0;
    for (var i = at; i < at + n; i++) {
      final d = s.codeUnitAt(i) - 0x30;
      if (d < 0 || d > 9) return -1;
      v = v * 10 + d;
    }
    return v;
  }

  final year = digits(0, 4), month = digits(4, 2), day = digits(6, 2);
  final hour = digits(8, 2), minute = digits(10, 2);
  if (year < 0 || month < 0 || day < 0 || hour < 0 || minute < 0) return null;
  var i = 12;
  var second = digits(12, 2);
  if (second < 0) {
    second = 0;
  } else {
    i = 14;
  }
  final base = DateTime.utc(year, month, day, hour, minute, second);
  while (i < s.length && _isSpace(s.codeUnitAt(i))) {
    i++;
  }
  // `+hhmm`, `-hhmm` or `+hh:mm`; anything else means UTC.
  if (i >= s.length) return base;
  final signChar = s.codeUnitAt(i);
  if (signChar != 0x2b && signChar != 0x2d) return base;
  final hours = digits(i + 1, 2);
  if (hours < 0) return base;
  var j = i + 3;
  if (j < s.length && s.codeUnitAt(j) == 0x3a) j++;
  final mins = digits(j, 2);
  if (mins < 0) return base;
  var minutes = (signChar == 0x2d ? -1 : 1) * (hours * 60 + mins);
  if (channelId != null) {
    minutes = fixEuropeanOffset(base, minutes, channelId);
  }
  return base.subtract(Duration(minutes: minutes));
}

bool _isSpace(int c) =>
    c == 0x20 || (c >= 0x09 && c <= 0x0d) || c == 0xa0 || c == 0xfeff;

/// Standard offsets, in minutes, of the countries on the EU summer time
/// rule, by the country suffix guides put on channel ids (`Rai1.it`).
const _europeanZones = {
  'uk': 0, 'gb': 0, 'ie': 0, 'pt': 0, //
  'it': 60, 'de': 60, 'fr': 60, 'es': 60, 'at': 60, 'ch': 60, 'nl': 60,
  'be': 60, 'lu': 60, 'pl': 60, 'cz': 60, 'sk': 60, 'hu': 60, 'si': 60,
  'hr': 60, 'ba': 60, 'rs': 60, 'me': 60, 'mk': 60, 'al': 60, 'dk': 60,
  'se': 60, 'no': 60, 'mt': 60, 'sm': 60, 'va': 60, 'ad': 60, 'mc': 60,
  'li': 60, //
  'gr': 120, 'ro': 120, 'bg': 120, 'fi': 120, 'ee': 120, 'lv': 120,
  'lt': 120, 'cy': 120, 'ua': 120,
};

/// The offset (minutes) [local] really has in the country of [channelId].
///
/// Only an offset that is one of the country's two (standard or summer)
/// but wrong for the date is changed; anything else, including channels of
/// other countries or regions with their own time (`+0000` for the Canary
/// Islands), is returned as given.
int fixEuropeanOffset(DateTime local, int offset, String channelId) {
  final dot = channelId.lastIndexOf('.');
  if (dot < 0) return offset;
  final std = _europeanZones[channelId.substring(dot + 1).toLowerCase()];
  if (std == null || (offset != std && offset != std + 60)) return offset;
  final valid = _isSummer(local.subtract(Duration(minutes: offset))) ==
      (offset == std + 60);
  if (valid) return offset;
  return offset == std ? std + 60 : std;
}

/// EU summer time: from 01:00 UTC on the last Sunday of March to 01:00 UTC
/// on the last Sunday of October.
bool _isSummer(DateTime utc) {
  DateTime lastSunday(int month) {
    final last = DateTime.utc(utc.year, month + 1, 0, 1);
    return last.subtract(Duration(days: last.weekday % 7));
  }

  return !utc.isBefore(lastSunday(3)) && utc.isBefore(lastSunday(10));
}
