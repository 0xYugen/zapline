/// Show-or-hide rules for channel groups, the way IPTV users trim provider
/// lists ("only Italian groups", "hide adult and VOD").
///
/// Each term is matched case-insensitively against the group title:
///
/// * a plain word (`IT`, `sport`) must appear as a whole word, so `IT`
///   matches "IT | Sport" and "IT: News" but not "Hits" or "British";
/// * a word ending in `*` (`ital*`) matches word prefixes: Italia, Italy;
/// * a term containing other characters (`IT|`, `[IT]`, `4K-`) is matched as
///   plain text anywhere in the title, ignoring spaces.
///
/// A group is hidden when it matches any exclude term, or when include terms
/// exist and it matches none. Exclusions win.
class GroupFilter {
  const GroupFilter({this.include = const [], this.exclude = const []});

  final List<String> include;
  final List<String> exclude;

  static const none = GroupFilter();

  bool get isEmpty => include.isEmpty && exclude.isEmpty;

  /// Parses a comma or newline separated list as typed by a user.
  static List<String> parseTerms(String text) => [
        for (final t in text.split(RegExp(r'[,\n]')))
          if (t.trim().isNotEmpty) t.trim(),
      ];

  bool hides(String? groupTitle) {
    final title = (groupTitle ?? '').toLowerCase();
    final words = _words(title);
    bool matches(String term) {
      final t = term.toLowerCase();
      if (t.endsWith('*') && _isWord(t.substring(0, t.length - 1))) {
        final prefix = t.substring(0, t.length - 1);
        return prefix.isNotEmpty && words.any((w) => w.startsWith(prefix));
      }
      if (_isWord(t)) return words.contains(t);
      // Literal terms ignore spaces: "IT|" matches "IT | Sport".
      return title.replaceAll(' ', '').contains(t.replaceAll(' ', ''));
    }

    if (exclude.any(matches)) return true;
    if (include.isNotEmpty && !include.any(matches)) return true;
    return false;
  }

  static final _wordRe = RegExp(r'^[\p{L}\p{N}]+$', unicode: true);
  static final _splitRe = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

  static bool _isWord(String s) => _wordRe.hasMatch(s);

  static Set<String> _words(String s) =>
      s.split(_splitRe).where((w) => w.isNotEmpty).toSet();

  Map<String, Object?> toJson() => {'include': include, 'exclude': exclude};

  factory GroupFilter.fromJson(Object? json) {
    if (json is! Map) return none;
    List<String> list(Object? v) => [
          for (final e in (v as List?) ?? const []) '$e',
        ];
    return GroupFilter(
      include: list(json['include']),
      exclude: list(json['exclude']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GroupFilter &&
      _sameList(other.include, include) &&
      _sameList(other.exclude, exclude);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(include), Object.hashAll(exclude));

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
