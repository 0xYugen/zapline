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
/// (case-insensitive), then normalised display name, then a looser name
/// ([looseChannelKey]: "Rai Uno" = "Rai 1") when only one guide channel has
/// it. Fuzzier strategies are left out: a wrong guide is worse than no
/// guide, and unmatched channels are offered for manual mapping instead.
///
/// Guide channels in [empty] carry no real programmes (only fillers such
/// as "No Game Today", see [isFillerTitle]): another guide's channel of
/// the same name wins over them. Free guides list DAZN's event feeds as
/// "DAZN1.it" next to the real DAZN 1 schedule under another id.
class ChannelMatcher {
  ChannelMatcher(Iterable<XmltvChannel> guideChannels,
      {Map<String, String> manualOverrides = const {},
      Set<String> empty = const {}})
      : _manual = manualOverrides,
        _empty = empty {
    // Channels with programmes first: the first of a name is kept.
    final ordered = [
      for (final gc in guideChannels)
        if (!empty.contains(gc.id)) gc,
      for (final gc in guideChannels)
        if (empty.contains(gc.id)) gc,
    ];
    for (final gc in ordered) {
      _byId.putIfAbsent(gc.id.toLowerCase(), () => gc.id);
      for (final n in gc.displayNames) {
        final key = normalizeChannelName(n);
        if (key.isNotEmpty) _byName.putIfAbsent(key, () => gc.id);
      }
      // Ids like "Canale5.it" double as names.
      final idName = normalizeChannelName(gc.id.split('.').first);
      if (idName.isNotEmpty) _byName.putIfAbsent(idName, () => gc.id);
      for (final key in {
        for (final n in [...gc.displayNames, gc.id.split('.').first])
          looseChannelKey(n),
      }) {
        if (key.isEmpty) continue;
        // An empty channel never makes a loose name with data ambiguous.
        final known = _byLoose[key];
        if (empty.contains(gc.id) && known != null && !empty.contains(known)) {
          continue;
        }
        // Two guide channels with the same loose name: ambiguous, unused.
        _byLoose[key] =
            _byLoose.containsKey(key) && _byLoose[key] != gc.id ? null : gc.id;
      }
    }
  }

  final Map<String, String> _manual;
  final Set<String> _empty;
  final _byId = <String, String>{};
  final _byName = <String, String>{};
  final _byLoose = <String, String?>{};

  /// [channelKey] identifies the channel for manual overrides
  /// (e.g. `"$sourceId/$id"`).
  EpgMatch? match(Channel channel, {String? channelKey}) {
    final manual = _manual[channelKey ?? '${channel.sourceId}/${channel.id}'];
    if (manual != null) return EpgMatch(manual, MatchKind.manual);

    final epgId = channel.epgChannelId;
    if (epgId != null && epgId.isNotEmpty) {
      final hit = _byId[epgId.toLowerCase()];
      if (hit != null) {
        // The id given has nothing to show: the name may find a guide
        // that does.
        if (_empty.contains(hit)) {
          final other = _byNames(channel.name);
          if (other != null && !_empty.contains(other.guideChannelId)) {
            return other;
          }
        }
        return EpgMatch(hit, MatchKind.epgId);
      }
    }
    return _byNames(channel.name);
  }

  EpgMatch? _byNames(String name) {
    final byName = _byName[normalizeChannelName(name)];
    if (byName != null) return EpgMatch(byName, MatchKind.name);
    final loose = _byLoose[looseChannelKey(name)];
    if (loose != null) return EpgMatch(loose, MatchKind.name);
    return null;
  }
}

/// Titles free guides put in place of a schedule they don't have.
bool isFillerTitle(String title) =>
    fillerTitles.contains(title.trim().toLowerCase());

const fillerTitles = {
  'no game today',
  'no data',
  'no event',
  'no events',
  'no events today',
  'no information',
  'no programme information',
  'no program information',
  'nessun evento',
  'nessun evento in onda',
  'programma non disponibile',
  'informazioni non disponibili',
};

/// Which guide channels a set of channels could use: every key the
/// [ChannelMatcher] might link them by. Big free guides list thousands of
/// channels; the programmes of the ones no channel can use need not be
/// stored (see `XmltvParser.wanted`).
///
/// It errs on the side of keeping: a guide channel is wanted when any of
/// its keys is one a channel has, even where the matcher would find the
/// key ambiguous and link nothing.
class GuideWants {
  /// [channels] are (epg id, name) pairs; [guideIds] the guide channels
  /// linked by hand or by an earlier match, which stay wanted whatever
  /// their names.
  GuideWants(
    Iterable<(String? epgId, String name)> channels, {
    Iterable<String> guideIds = const [],
  }) {
    for (final (epgId, name) in channels) {
      if (epgId != null && epgId.isNotEmpty) _ids.add(epgId.toLowerCase());
      final n = normalizeChannelName(name);
      if (n.isNotEmpty) _names.add(n);
      final l = looseChannelKey(name);
      if (l.isNotEmpty) _loose.add(l);
    }
    for (final id in guideIds) {
      _ids.add(id.toLowerCase());
    }
  }

  final _ids = <String>{};
  final _names = <String>{};
  final _loose = <String>{};

  bool get isEmpty => _ids.isEmpty && _names.isEmpty && _loose.isEmpty;

  /// Whether a channel could be linked to [gc].
  bool call(XmltvChannel gc) {
    if (_ids.contains(gc.id.toLowerCase())) return true;
    final idName = gc.id.split('.').first;
    for (final n in [...gc.displayNames, idName]) {
      if (_names.contains(normalizeChannelName(n)) ||
          _loose.contains(looseChannelKey(n))) {
        return true;
      }
    }
    return false;
  }

  /// Changes when the set of keys changes, in any order: a guide imported
  /// for other channels is downloaded again rather than kept as it was.
  String get fingerprint {
    // FNV-1a over the sorted keys, kept to 32 bits.
    var h = 0x811c9dc5;
    for (final set in [_ids, _names, _loose]) {
      for (final k in set.toList()..sort()) {
        for (final c in k.codeUnits) {
          h = ((h ^ c) * 0x01000193) & 0xffffffff;
        }
        h = ((h ^ 0x0a) * 0x01000193) & 0xffffffff;
      }
      h = ((h ^ 0x1e) * 0x01000193) & 0xffffffff;
    }
    final n = _ids.length + _names.length + _loose.length;
    return '${h.toRadixString(16).padLeft(8, '0')}-$n';
  }
}

// `[IT]`, `(IT)`, `IT:`, `IT |`, `|IT|` and `IT - ` (a spaced dash, so names
// like "Rai-Sport" are left alone).
final _prefix = RegExp(
    r'^\s*(?:\[[^\]]{1,12}\]|\([^)]{1,12}\)|\|[a-z]{2,3}\||'
    r'[a-z]{2,3}\s*[:|]+|[a-z]{2}\s+-\s+)\s*',
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

/// [s] with the accented letters of [_diacritics] replaced; [s] itself
/// (no copy) when it has none, as most channel names.
String _stripAccents(String s) {
  var i = 0;
  // All the accented letters are at U+00DF and above.
  while (i < s.length && s.codeUnitAt(i) < 0xdf) {
    i++;
  }
  if (i == s.length) return s;
  final b = StringBuffer(s.substring(0, i));
  for (; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    if (c < 0xdf) {
      b.writeCharCode(c);
    } else {
      final ch = String.fromCharCode(c);
      b.write(_diacritics[ch] ?? ch);
    }
  }
  return b.toString();
}

/// Reduces a channel name to a comparison key: lower case, no accents, no
/// country prefix (`IT:`, `[UK]`), no quality tags (`HD`, `4K`, `HEVC`), no
/// punctuation. `+1` style timeshift suffixes are kept because they are
/// different channels.
String normalizeChannelName(String name) {
  var s = name.toLowerCase();
  s = _stripAccents(s);
  s = s.replaceFirst(_prefix, '');
  s = s.replaceAll(_quality, ' ');
  s = s.replaceAll(_nonAlnum, '');
  return s;
}

const _numberWords = {
  'uno': '1',
  'due': '2',
  'tre': '3',
  'quattro': '4',
  'cinque': '5',
  'sei': '6',
  'sette': '7',
  'otto': '8',
  'dieci': '10',
  'one': '1',
  'two': '2',
  'three': '3',
  'four': '4',
  'five': '5',
};

/// Words that tell nothing about which channel it is when they come last
/// ("Discovery Italia", "Cielo TV").
const _tailWords = {'italia', 'italy', 'it', 'tv', 'channel', 'hd'};

final _wordSplit = RegExp(r'[^a-z0-9+]+');

/// A looser comparison key than [normalizeChannelName]: number words become
/// digits ("Rai Uno" = "Rai 1") and a trailing "Italia", "TV" or "Channel"
/// goes. Matched only when a single guide channel has the key.
String looseChannelKey(String name) {
  var s = name.toLowerCase();
  s = _stripAccents(s);
  s = s.replaceFirst(_prefix, '');
  s = s.replaceAll(_quality, ' ');
  final words = [
    for (final w in s.split(_wordSplit))
      if (w.isNotEmpty) _numberWords[w] ?? w,
  ];
  while (words.length > 1 && _tailWords.contains(words.last)) {
    words.removeLast();
  }
  return words.join();
}

/// Ranks guide channels as candidates for a channel the automatic matcher
/// could not link, best first. Used by the manual mapping screen, so it
/// favours recall: exact normalised names, then containment, then shared
/// words.
List<(XmltvChannel, double)> rankGuideCandidates(
  String channelName,
  Iterable<XmltvChannel> guideChannels, {
  int limit = 8,
}) =>
    GuideIndex(guideChannels).rank(channelName, limit: limit);

/// Guide channels with their names already normalised, for ranking many
/// channels against the same guide (see [rankGuideCandidates]).
class GuideIndex {
  GuideIndex(Iterable<XmltvChannel> guideChannels)
      : _entries = [
          for (final gc in guideChannels)
            (
              gc,
              [
                for (final name in [...gc.displayNames, gc.id.split('.').first])
                  (normalizeChannelName(name), _words(name)),
              ],
            ),
        ];

  final List<(XmltvChannel, List<(String, Set<String>)>)> _entries;

  /// Best candidates for [channelName], best first.
  List<(XmltvChannel, double)> rank(String channelName, {int limit = 8}) {
    final target = normalizeChannelName(channelName);
    final targetWords = _words(channelName);
    if (target.isEmpty && targetWords.isEmpty) return const [];

    final scored = <(XmltvChannel, double)>[];
    for (final (gc, names) in _entries) {
      var best = 0.0;
      for (final (n, words) in names) {
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
          // Counted without building sets: this runs for every guide name
          // against every channel being matched.
          var shared = 0;
          for (final w in words) {
            if (targetWords.contains(w)) shared++;
          }
          if (shared > 0) {
            final union = words.length + targetWords.length - shared;
            s = 0.6 * shared / union;
          } else {
            // Prefix matches catch abbreviations ("Cinema 1" vs "Cinema
            // One").
            final prefix = words.any((w) => targetWords.any((t) =>
                w.length >= 3 &&
                t.length >= 3 &&
                (w.startsWith(t) || t.startsWith(w))));
            s = prefix ? 0.3 : 0;
          }
        }
        if (s > best) best = s;
      }
      if (best > 0.15) scored.add((gc, best));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).toList();
  }
}

final _wordSplitter = RegExp(r'[^a-z0-9+]+');

Set<String> _words(String s) {
  var t = s.toLowerCase();
  t = _stripAccents(t);
  t = t.replaceFirst(_prefix, '').replaceAll(_quality, ' ');
  return t.split(_wordSplitter).where((w) => w.isNotEmpty).toSet();
}
