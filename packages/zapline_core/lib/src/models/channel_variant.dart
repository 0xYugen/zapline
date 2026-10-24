/// Picture quality a channel's name advertises.
enum VideoQuality {
  unknown,
  sd,
  hd,
  fhd,
  uhd;

  /// Badge text: "4K", "FHD", "HD", "SD"; `null` when the name says nothing.
  String? get label => switch (this) {
        unknown => null,
        sd => 'SD',
        hd => 'HD',
        fhd => 'FHD',
        uhd => '4K',
      };
}

/// Providers list the same channel several times, one per quality or as a
/// backup ("Rai 1 HD", "RAI 1 FHD", "IT | Rai 1 4K", "Rai 1 (backup)").
/// This splits a name into what identifies the channel and its quality, so
/// the versions can be shown as one.
class ChannelVariant {
  const ChannelVariant._(this.key, this.baseName, this.quality);

  /// Identifies the channel across versions: lower case letters and digits
  /// of the name without quality or codec words.
  final String key;

  /// The name without quality or codec words, as written ("IT | Rai 1").
  final String baseName;
  final VideoQuality quality;

  static const _qualities = {
    '4k': VideoQuality.uhd,
    '8k': VideoQuality.uhd,
    'uhd': VideoQuality.uhd,
    '2160p': VideoQuality.uhd,
    '2160': VideoQuality.uhd,
    'ᵁᴴᴰ': VideoQuality.uhd,
    'fhd': VideoQuality.fhd,
    'fullhd': VideoQuality.fhd,
    '1080p': VideoQuality.fhd,
    '1080i': VideoQuality.fhd,
    '1080': VideoQuality.fhd,
    'ᶠᴴᴰ': VideoQuality.fhd,
    'hd': VideoQuality.hd,
    'hq': VideoQuality.hd,
    '720p': VideoQuality.hd,
    '720': VideoQuality.hd,
    'ᴴᴰ': VideoQuality.hd,
    'sd': VideoQuality.sd,
    'lq': VideoQuality.sd,
    '576p': VideoQuality.sd,
    '480p': VideoQuality.sd,
  };

  /// Words that tell versions apart without being part of the name.
  static const _noise = {
    'hevc',
    'h265',
    'h264',
    'x265',
    'x264',
    '50fps',
    '60fps',
    'backup',
    'bk',
    'alt',
    'raw',
  };

  // A word: letters, digits and the superscript quality marks; "H.265" and
  // "Full HD" are joined first.
  static final _word = RegExp(r'[\p{L}\p{N}ᴴᴰᵁᶠ]+', unicode: true);
  static final _joined =
      RegExp(r'\b(h)\.(26[45])\b|\bfull\s+hd\b', caseSensitive: false);
  static final _edges = RegExp(r'^[\s\-_|:/.,·•]+|[\s\-_|:/.,·•(\[]+$');
  static final _emptyBrackets = RegExp(r'[\(\[]\s*[\)\]]');
  static final _spaces = RegExp(r'\s{2,}');

  static ChannelVariant parse(String name) {
    final text = name.replaceAllMapped(
      _joined,
      (m) => m.group(1) != null ? '${m.group(1)}${m.group(2)}' : 'fullhd',
    );
    var quality = VideoQuality.unknown;
    final kept = StringBuffer();
    final keyBuf = StringBuffer();
    var last = 0;
    for (final m in _word.allMatches(text)) {
      final w = m.group(0)!;
      final lower = w.toLowerCase();
      final q = _qualities[lower] ?? _qualities[w];
      if (q != null || _noise.contains(lower)) {
        if (q != null && q.index > quality.index) quality = q;
        kept.write(text.substring(last, m.start));
        last = m.end;
        continue;
      }
      kept.write(text.substring(last, m.end));
      last = m.end;
      keyBuf.write(lower);
    }
    kept.write(text.substring(last));
    var base = kept
        .toString()
        .replaceAll(_emptyBrackets, ' ')
        .replaceAll(_spaces, ' ')
        .replaceAll(_edges, '')
        .trim();
    var key = keyBuf.toString();
    // A name that is only quality words ("4K") keeps itself.
    if (key.isEmpty) {
      base = name.trim();
      key = name.toLowerCase();
    }
    return ChannelVariant._(key, base, quality);
  }
}
