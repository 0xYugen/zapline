import '../models/channel.dart';
import '../xmltv/xmltv_parser.dart';

/// How a channel was linked to a guide channel; shown to the user so they can
/// review weak matches.
enum MatchKind { manual, epgId, name }

class EpgMatch {
  const EpgMatch(this.guideChannelId, this.kind);

  final String guideChannelId;
  final MatchKind kind;
}

/// Links source channels to XMLTV channels.
///
/// Order: user overrides, then exact `tvg-id`/`epg_channel_id`
/// (case-insensitive), then normalised display name. Fuzzier strategies are
/// deliberately left out: a wrong guide is worse than no guide, and unmatched
/// channels are offered to the user for manual mapping instead.
class ChannelMatcher {
  ChannelMatcher(Iterable<XmltvChannel> guideChannels,
      {Map<String, String> manualOverrides = const {}})
      : _manual = manualOverrides {
    for (final gc in guideChannels) {
      _byId.putIfAbsent(gc.id.toLowerCase(), () => gc.id);
      for (final n in gc.displayNames) {
        final key = normalizeChannelName(n);
        if (key.isNotEmpty) _byName.putIfAbsent(key, () => gc.id);
      }
      // Ids like "Canale5.it" double as names.
      final idName = normalizeChannelName(gc.id.split('.').first);
      if (idName.isNotEmpty) _byName.putIfAbsent(idName, () => gc.id);
    }
  }

  final Map<String, String> _manual;
  final _byId = <String, String>{};
  final _byName = <String, String>{};

  /// [channelKey] identifies the channel for manual overrides
  /// (e.g. `"$sourceId/$id"`).
  EpgMatch? match(Channel channel, {String? channelKey}) {
    final manual = _manual[channelKey ?? '${channel.sourceId}/${channel.id}'];
    if (manual != null) return EpgMatch(manual, MatchKind.manual);

    final epgId = channel.epgChannelId;
    if (epgId != null && epgId.isNotEmpty) {
      final hit = _byId[epgId.toLowerCase()];
      if (hit != null) return EpgMatch(hit, MatchKind.epgId);
    }

    final byName = _byName[normalizeChannelName(channel.name)];
    if (byName != null) return EpgMatch(byName, MatchKind.name);
    return null;
  }
}

final _prefix = RegExp(
    r'^\s*(?:\[[^\]]{1,12}\]|\([^)]{1,12}\)|[a-z]{2,3}\s*[:|]+)\s*',
    caseSensitive: false);
final _quality = RegExp(
    r'\b(?:uhd|fhd|hd|sd|hq|4k|8k|1080p?|720p?|h\.?265|h\.?264|hevc|backup|bk|vip|raw)\b',
    caseSensitive: false);
final _nonAlnum = RegExp(r'[^a-z0-9+]+');

const _diacritics = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'å': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ñ': 'n',
  'ç': 'c',
  'ß': 'ss',
};

/// Reduces a channel name to a comparison key: lower case, no accents, no
/// country prefix (`IT:`, `[UK]`), no quality tags (`HD`, `4K`, `HEVC`), no
/// punctuation. `+1` style timeshift suffixes are kept because they are
/// different channels.
String normalizeChannelName(String name) {
  var s = name.toLowerCase();
  s = s.split('').map((c) => _diacritics[c] ?? c).join();
  s = s.replaceFirst(_prefix, '');
  s = s.replaceAll(_quality, ' ');
  s = s.replaceAll(_nonAlnum, '');
  return s;
}

/// Ranks guide channels as candidates for a channel the automatic matcher
/// could not link, best first. Used by the manual mapping screen, so it
/// favours recall: exact normalised names, then containment, then shared
/// words.
List<(XmltvChannel, double)> rankGuideCandidates(
  String channelName,
  Iterable<XmltvChannel> guideChannels, {
  int limit = 8,
}) {
  final target = normalizeChannelName(channelName);
  final targetWords = _words(channelName);
  if (target.isEmpty && targetWords.isEmpty) return const [];

  final scored = <(XmltvChannel, double)>[];
  for (final gc in guideChannels) {
    var best = 0.0;
    for (final name in [...gc.displayNames, gc.id.split('.').first]) {
      final n = normalizeChannelName(name);
      if (n.isEmpty) continue;
      double s;
      if (n == target) {
        s = 1.0;
      } else if (target.isNotEmpty &&
          (n.contains(target) || target.contains(n))) {
        s = 0.8 *
                (n.length < target.length
                    ? n.length / target.length
                    : target.length / n.length) +
            0.1;
      } else {
        final words = _words(name);
        final shared = words.intersection(targetWords).length;
        // Prefix matches catch abbreviations ("Cinema 1" vs "Cinema One").
        final prefix = words.any((w) => targetWords.any((t) =>
                w.length >= 3 &&
                t.length >= 3 &&
                (w.startsWith(t) || t.startsWith(w))))
            ? 0.5
            : 0.0;
        final union = words.union(targetWords).length;
        s = union == 0 ? 0 : 0.6 * shared / union;
        if (shared == 0) s = prefix * 0.6;
      }
      if (s > best) best = s;
    }
    if (best > 0.15) scored.add((gc, best));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.take(limit).toList();
}

Set<String> _words(String s) {
  var t = s.toLowerCase();
  t = t.split('').map((c) => _diacritics[c] ?? c).join();
  t = t.replaceFirst(_prefix, '').replaceAll(_quality, ' ');
  return t.split(RegExp(r'[^a-z0-9+]+')).where((w) => w.isNotEmpty).toSet();
}
