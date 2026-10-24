import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import 'secret_store.dart';
import 'format.dart';
import 'free_epg.dart';
import 'settings.dart';

/// What the user typed or pasted on the "add source" screen.
class SourceInput {
  const SourceInput({
    required this.url,
    this.username = '',
    this.password = '',
    this.guideUrl = '',
  });

  final String url;
  final String username;
  final String password;

  /// Optional extra XMLTV guide.
  final String guideUrl;

  List<String> get _guides =>
      guideUrl.trim().isEmpty ? const [] : [guideUrl.trim()];

  /// Builds the record to persist: explicit credentials or credentials found
  /// in the URL mean Xtream, anything else is an M3U playlist.
  SourceRecord toRecord(String id) {
    final trimmed = url.trim();
    if (username.isNotEmpty) {
      final u = Uri.parse(
        trimmed.contains('://') ? trimmed : 'http://$trimmed',
      );
      return SourceRecord(
        id: id,
        kind: SourceKind.xtream,
        name: u.host,
        url: trimmed,
        username: username.trim(),
        password: password,
        extraGuideUrls: _guides,
      );
    }
    final creds = detectXtreamCredentials(trimmed);
    if (creds != null) {
      return SourceRecord(
        id: id,
        kind: SourceKind.xtream,
        name: creds.baseUrl.host,
        url: creds.baseUrl.toString(),
        username: creds.username,
        password: creds.password,
        extraGuideUrls: _guides,
      );
    }
    return SourceRecord(
      id: id,
      kind: SourceKind.m3u,
      name: Uri.tryParse(trimmed)?.host ?? trimmed,
      url: trimmed,
      extraGuideUrls: _guides,
    );
  }
}

typedef SyncRunner = Future<SyncResult> Function(
  SourceRecord source,
  void Function(SyncProgress) onProgress,
);

/// Runs [SourceSync] on a background isolate with its own database
/// connection, so parsing a large guide never blocks the UI.
/// [guideDays] is read at each sync, so a settings change applies to the
/// next refresh.
SyncRunner isolateSyncRunner(String dbPath, {int Function()? guideDays}) =>
    (source, onProgress) async {
      final port = ReceivePort();
      final send = port.sendPort;
      final sub = port.listen((m) => onProgress(m as SyncProgress));
      try {
        return await _syncInIsolate(
          dbPath,
          source,
          send,
          guideDays?.call() ?? 7,
        );
      } finally {
        await sub.cancel();
        port.close();
      }
    };

// Kept separate so the closure sent to the isolate captures only these three
// sendable values, not the caller's scope (which holds the app state).
Future<SyncResult> _syncInIsolate(
  String dbPath,
  SourceRecord source,
  SendPort progress,
  int guideDays,
) => Isolate.run(() async {
  final db = ZaplineDatabase.open(dbPath);
  try {
    return await SourceSync(
      db,
      guideAhead: Duration(days: guideDays),
    ).sync(source, onProgress: progress.send);
  } finally {
    db.close();
  }
});

/// App-wide state backed by the local database.
class AppState extends ChangeNotifier {
  AppState(
    this.db, {
    required this.syncRunner,
    SecretStore? secrets,
    this.guideFetcher,
    this.vod,
  }) : secrets = secrets ?? MemorySecretStore() {
    _upgradeFreeEpgs();
    _reload();
  }

  /// Sources using a country's free EPG get guides added to the catalogue
  /// since, without asking again.
  void _upgradeFreeEpgs() {
    for (final s in db.sources()) {
      final missing = [
        for (final c in FreeEpg.countries)
          if (c.urls.any(s.extraGuideUrls.contains))
            for (final u in c.urls)
              if (!s.extraGuideUrls.contains(u)) u,
      ];
      if (missing.isEmpty) continue;
      db.saveSource(
        s.copyWith(extraGuideUrls: [...s.extraGuideUrls, ...missing]),
      );
    }
  }

  final ZaplineDatabase db;
  final SyncRunner syncRunner;
  final SecretStore secrets;

  /// Passwords loaded from [secrets], by source id.
  final _passwords = <String, String>{};

  /// False when the platform keystore failed (e.g. no libsecret on a Linux
  /// desktop); passwords then stay in the database as before.
  bool _keystoreWorks = true;

  static String _secretKey(String sourceId) => 'source:$sourceId:password';

  /// Loads passwords from the keystore, moving any still stored in the
  /// database (older versions) into it. Call once before showing the UI.
  Future<void> loadSecrets() => _secretsLoading ??= _loadSecrets();

  /// Set once loading starts; syncs wait for it so they never run with a
  /// password that has not been read yet.
  Future<void>? _secretsLoading;

  Future<void> _loadSecrets() async {
    for (final s in db.sources()) {
      try {
        if (s.password.isNotEmpty) {
          await secrets.write(_secretKey(s.id), s.password);
          db.saveSource(s.copyWith(password: ''));
          _passwords[s.id] = s.password;
        } else {
          final pw = await secrets.read(_secretKey(s.id));
          if (pw != null) _passwords[s.id] = pw;
        }
      } catch (e) {
        _keystoreWorks = false;
        debugPrint('Keystore unavailable, passwords stay local: $e');
        break;
      }
    }
    _reload();
    notifyListeners();
  }

  List<SourceRecord> sources = const [];
  Set<String> _favouriteKeys = const {};
  List<String> groups = const [];
  int channelCount = 0;

  /// Progress of the sync in flight, if any.
  SyncProgress? progress;
  String? syncingSourceId;

  bool get isEmpty => channelCount == 0 && movieCount == 0 && showCount == 0;

  /// Films and series across sources.
  int movieCount = 0;
  int showCount = 0;
  bool get hasMovies => movieCount > 0;
  bool get hasShows => showCount > 0;
  bool get isSyncing => syncingSourceId != null;

  /// Incremented whenever stored channels change; screens use it to cache
  /// query results.
  int version = 0;

  void _reload() {
    version++;
    sources = [
      for (final s in db.sources())
        s.password.isEmpty && _passwords.containsKey(s.id)
            ? s.copyWith(password: _passwords[s.id])
            : s,
    ];
    groups = db.groups();
    lockedGroups = db.lockedGroups();
    channelCount = db.channelCount();
    movieCount = db.movieCount();
    showCount = db.showCount();
    _favouriteKeys = db.favouriteKeys();
  }

  // ------------------------------------------------------ preferences

  /// User preferences, stored in the database.
  late final settings = AppSettings(db);

  /// Parental lock opened with the PIN for this session.
  bool unlocked = false;

  Set<String> lockedGroups = const {};

  ChannelVisibility get _visibility =>
      unlocked ? ChannelVisibility.unlocked : ChannelVisibility.visible;

  bool isLocked(String group) => !unlocked && lockedGroups.contains(group);

  bool get hasPin => settings.pinHash != null;

  static String _hash(String pin) =>
      sha256.convert(utf8.encode('zapline-pin:$pin')).toString();

  void setPin(String? pin) {
    settings.pinHash = pin == null ? null : _hash(pin);
    if (pin == null) {
      // No PIN means nothing can stay locked.
      for (final s in sources) {
        for (final g in db.groupInfo(s.id)) {
          if (g.locked) db.setGroupLocked(s.id, g.title, false);
        }
      }
    }
    _reload();
    notifyListeners();
  }

  /// Opens locked groups for this session when [pin] is right.
  bool unlock(String pin) {
    if (settings.pinHash != _hash(pin)) return false;
    unlocked = true;
    _reload();
    notifyListeners();
    return true;
  }

  void lock() {
    unlocked = false;
    _reload();
    notifyListeners();
  }

  /// Redraws screens after a preference changed.
  void settingsChanged() {
    _reload();
    notifyListeners();
  }

  /// Clock time in the user's 12/24-hour format.
  String time(DateTime t) => formatTime(t, h24: settings.clock24h);

  /// Number shown and dialled for [c] at [index] in its list.
  int channelNumber(Channel c, int index) =>
      settings.sequentialNumbers ? index + 1 : (c.number ?? index + 1);

  // --------------------------------------------------------- channels

  List<Channel> channels({String? group}) =>
      _mergeVersions(db.channels(group: group, visibility: _visibility));

  List<Channel> search(String query) =>
      _mergeVersions(db.search(query, visibility: _visibility));

  // ------------------------------------------------ versions of a channel

  /// Every version of a merged channel by each version's key; rebuilt as
  /// lists are merged, dropped when the stored channels change.
  final _versions = <String, List<Channel>>{};
  int _versionsAt = -1;

  static final _parsed = <String, ChannelVariant>{};

  static ChannelVariant _variant(String name) =>
      _parsed[name] ??= ChannelVariant.parse(name);

  static String _versionKey(Channel c) =>
      '${c.sourceId}\u0000${_variant(c.name).key}';

  /// Order of preference: best picture first, or HD first to save data.
  int _rank(VideoQuality q) => settings.saveData
      ? switch (q) {
          VideoQuality.hd || VideoQuality.unknown => 0,
          VideoQuality.sd => 1,
          VideoQuality.fhd => 2,
          VideoQuality.uhd => 3,
        }
      : -(q == VideoQuality.unknown ? VideoQuality.hd.index : q.index);

  /// One entry per channel: its versions ("HD", "FHD", "4K", backups) fold
  /// into the preferred one, at the place of the first.
  List<Channel> _mergeVersions(List<Channel> list) {
    if (!settings.mergeVersions || list.length < 2) return list;
    if (_versionsAt != version) {
      _versions.clear();
      _versionsAt = version;
    }
    final byKey = <String, List<Channel>>{};
    for (final c in list) {
      (byKey[_versionKey(c)] ??= []).add(c);
    }
    if (byKey.length == list.length) return list;
    final choices = settings.versionChoices;
    final out = <Channel>[];
    for (final c in list) {
      final key = _versionKey(c);
      final group = byKey[key];
      if (group == null) continue;
      byKey.remove(key);
      if (group.length == 1) {
        out.add(c);
        continue;
      }
      final sorted = [...group]
        ..sort(
          (a, b) =>
              _rank(_variant(a.name).quality)
                  .compareTo(_rank(_variant(b.name).quality)),
        );
      for (final v in sorted) {
        _versions[ZaplineDatabase.channelKey(v)] = sorted;
      }
      final chosen = choices[key];
      out.add(
        sorted.firstWhere(
          (v) => ZaplineDatabase.channelKey(v) == chosen,
          orElse: () => sorted.first,
        ),
      );
    }
    return out;
  }

  /// The versions of [c] in order of preference; just [c] when it has none.
  List<Channel> versionsOf(Channel c) =>
      _versions[ZaplineDatabase.channelKey(c)] ?? [c];

  /// [c]'s name without the quality words when it stands for several
  /// versions ("Rai 1" for "Rai 1 FHD").
  String displayName(Channel c) =>
      versionsOf(c).length > 1 ? _variant(c.name).baseName : c.name;

  /// "4K", "FHD", "HD" or "SD" as [c]'s name says, if it says.
  String? qualityOf(Channel c) => _variant(c.name).quality.label;

  /// Plays [c] from now on when its channel is opened.
  void preferVersion(Channel c) {
    settings.versionChoices = {
      ...settings.versionChoices,
      _versionKey(c): ZaplineDatabase.channelKey(c),
    };
    _reload();
    notifyListeners();
  }

  /// Where [c], or another version of it, is in [list]; -1 if nowhere.
  int indexOfChannel(List<Channel> list, Channel c) {
    final exact = list.indexWhere(
      (e) => e.sourceId == c.sourceId && e.id == c.id,
    );
    if (exact >= 0) return exact;
    final key = _versionKey(c);
    return list.indexWhere((e) => _versionKey(e) == key);
  }

  List<(Channel, Programme)> searchProgrammes(String query) =>
      db.searchProgrammes(
        query,
        from: DateTime.now().toUtc().subtract(const Duration(days: 1)),
        visibility: _visibility,
      );

  List<Channel> favourites() => db.favourites(
    visibility: ChannelVisibility(hidden: true, locked: unlocked),
  );

  List<Channel> recents() => db.recents(visibility: _visibility);

  bool get hasRecents => db.recents(limit: 1).isNotEmpty;

  void markWatched(Channel c) => db.markWatched(c);

  /// The channel to reopen at startup, if the user wants that.
  Channel? get resumeChannel =>
      settings.resumeLastChannel ? recents().firstOrNull : null;

  void setChannelHidden(Channel c, bool hidden) {
    db.setChannelHidden(c, hidden);
    _reload();
    notifyListeners();
  }

  List<Channel> hiddenChannels(String sourceId) =>
      db.hiddenChannels(sourceId: sourceId);

  // ----------------------------------------------------- managing sources

  List<GroupInfo> groupInfo(String sourceId) => db.groupInfo(sourceId);

  /// Saves edits to a source (name, guides, filter, guide shift). The
  /// password stays wherever it already lives.
  void updateSource(SourceRecord record) {
    final keepPassword = !_passwords.containsKey(record.id);
    db.saveSource(keepPassword ? record : record.copyWith(password: ''));
    db.applyGroupVisibility(record.id, record.groupFilter);
    _reload();
    notifyListeners();
  }

  void setGroupHidden(SourceRecord s, String group, bool? hidden) {
    db.setGroupHidden(s.id, group, hidden);
    db.applyGroupVisibility(s.id, s.groupFilter);
    _reload();
    notifyListeners();
  }

  // ------------------------------------- categories of channels, films, series

  SourceRecord _record(String sourceId) =>
      sources.firstWhere((s) => s.id == sourceId);

  /// [sourceId]'s channel groups, or film or series categories, with
  /// whether each shows and why.
  List<CategoryInfo> categoriesOf(String sourceId, ContentKind kind) {
    if (kind == ContentKind.tv) {
      return [
        for (final g in db.groupInfo(sourceId))
          CategoryInfo(
            title: g.title,
            count: g.channels,
            hidden: g.hidden,
            explicit: g.explicit,
            locked: g.locked,
          ),
      ];
    }
    final s = _record(sourceId);
    final filter = filterOf(s, kind);
    final choices = kind == ContentKind.movies ? s.movieChoices : s.showChoices;
    final all = kind == ContentKind.movies
        ? db.movieCategories(sourceId: sourceId)
        : db.showCategories(sourceId: sourceId);
    return [
      for (final c in all)
        CategoryInfo(
          title: c.title,
          count: c.count,
          hidden:
              choices[c.title] ??
              filter.hides(c.title.isEmpty ? null : c.title),
          explicit: choices[c.title],
          locked: false,
        ),
    ];
  }

  GroupFilter filterOf(SourceRecord s, ContentKind kind) => switch (kind) {
    ContentKind.tv => s.groupFilter,
    ContentKind.movies => s.movieFilter,
    ContentKind.shows => s.showFilter,
  };

  /// Sets [kind]'s filter of [s]; with [resetChoices] hand-made choices go
  /// so the filter decides everything.
  void setFilter(
    SourceRecord s,
    ContentKind kind,
    GroupFilter filter, {
    bool resetChoices = false,
  }) {
    var record = switch (kind) {
      ContentKind.tv => s.copyWith(groupFilter: filter),
      ContentKind.movies => s.copyWith(movieFilter: filter),
      ContentKind.shows => s.copyWith(showFilter: filter),
    };
    if (resetChoices) {
      switch (kind) {
        case ContentKind.tv:
          for (final g in db.groupInfo(s.id)) {
            if (g.explicit != null) db.setGroupHidden(s.id, g.title, null);
          }
        case ContentKind.movies:
          record = record.copyWith(movieChoices: const {});
        case ContentKind.shows:
          record = record.copyWith(showChoices: const {});
      }
    }
    updateSource(record);
  }

  /// Shows (`false`) or hides (`true`) [titles] by hand; `null` lets the
  /// filter decide again.
  void setCategoriesHidden(
    String sourceId,
    ContentKind kind,
    Iterable<String> titles,
    bool? hidden,
  ) {
    final s = _record(sourceId);
    if (kind == ContentKind.tv) {
      for (final t in titles) {
        db.setGroupHidden(s.id, t, hidden);
      }
      db.applyGroupVisibility(s.id, s.groupFilter);
      _reload();
      notifyListeners();
      return;
    }
    final choices = {
      ...(kind == ContentKind.movies ? s.movieChoices : s.showChoices),
    };
    for (final t in titles) {
      if (hidden == null) {
        choices.remove(t);
      } else {
        choices[t] = hidden;
      }
    }
    updateSource(
      kind == ContentKind.movies
          ? s.copyWith(movieChoices: choices)
          : s.copyWith(showChoices: choices),
    );
  }

  /// [kind]'s filter and choices of [sourceId], to put back with [restore].
  CategorySnapshot snapshot(String sourceId, ContentKind kind) =>
      CategorySnapshot(
        sourceId: sourceId,
        kind: kind,
        filter: filterOf(_record(sourceId), kind),
        choices: {
          for (final c in categoriesOf(sourceId, kind)) c.title: c.explicit,
        },
      );

  void restore(CategorySnapshot snap) {
    final s = _record(snap.sourceId);
    if (snap.kind == ContentKind.tv) {
      for (final MapEntry(:key, :value) in snap.choices.entries) {
        db.setGroupHidden(s.id, key, value);
      }
      updateSource(s.copyWith(groupFilter: snap.filter));
      return;
    }
    final choices = {
      for (final MapEntry(:key, :value) in snap.choices.entries) key: ?value,
    };
    updateSource(
      snap.kind == ContentKind.movies
          ? s.copyWith(movieFilter: snap.filter, movieChoices: choices)
          : s.copyWith(showFilter: snap.filter, showChoices: choices),
    );
  }

  void setGroupLocked(SourceRecord s, String group, bool locked) {
    db.setGroupLocked(s.id, group, locked);
    _reload();
    notifyListeners();
  }

  /// What [filter] would leave visible on [sourceId], counting the user's
  /// explicit choices: (visible groups, all groups, visible channels).
  (int, int, int) previewFilter(String sourceId, GroupFilter filter) {
    var groups = 0, channels = 0;
    final all = db.groupInfo(sourceId);
    for (final g in all) {
      final hidden =
          g.explicit ?? filter.hides(g.title.isEmpty ? null : g.title);
      if (!hidden) {
        groups++;
        channels += g.channels;
      }
    }
    return (groups, all.length, channels);
  }

  bool get hasFavourites => _favouriteKeys.isNotEmpty;

  bool isFavourite(Channel c) =>
      _favouriteKeys.contains(ZaplineDatabase.channelKey(c));

  void toggleFavourite(Channel c) {
    db.setFavourite(c, !isFavourite(c));
    _reload();
    notifyListeners();
  }

  // ------------------------------------------------------ guide mapping

  (int, List<XmltvChannel>)? _guideCache;

  /// All guide channels; cached until the stored data changes.
  List<XmltvChannel> get guideChannels {
    final cached = _guideCache;
    if (cached != null && cached.$1 == version) return cached.$2;
    final list = db.guideChannels()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    _guideCache = (version, list);
    return list;
  }

  List<Channel> unmatchedChannels(String sourceId) =>
      db.unmatchedChannels(sourceId: sourceId);

  List<(XmltvChannel, double)> guideSuggestions(Channel c) =>
      rankGuideCandidates(c.name, guideChannels);

  /// Guide channels whose name or id contains [query].
  List<XmltvChannel> searchGuide(String query, {int limit = 30}) {
    final q = normalizeChannelName(query);
    if (q.isEmpty) return const [];
    return guideChannels
        .where(
          (g) =>
              normalizeChannelName(g.id).contains(q) ||
              g.displayNames.any((n) => normalizeChannelName(n).contains(q)),
        )
        .take(limit)
        .toList();
  }

  /// Links [c] to [guideId] for good; survives re-syncs.
  void assignGuide(Channel c, String guideId) {
    db.setGuideOverride(c, guideId);
    db.rebuildGuideLinks();
    _reload();
    notifyListeners();
  }

  /// The archive URL for [p] on [c], or `null` if it cannot be replayed.
  Uri? catchupUrl(Channel c, Programme p) {
    if (!canReplay(c, p)) return null;
    final source = sources.where((s) => s.id == c.sourceId).firstOrNull;
    return buildCatchupUrl(
      c,
      start: p.start,
      stop: p.stop,
      serverOffset: source?.serverOffset ?? Duration.zero,
    );
  }

  /// Programmes of one channel overlapping [from]–[to], in order.
  List<Programme> schedule(Channel c, DateTime from, DateTime to) {
    final list =
        guide([c], from, to)[ZaplineDatabase.channelKey(c)] ??
        const <Programme>[];
    if (list.isEmpty) _wantGuide(c);
    return list;
  }

  (Programme?, Programme?) nowNext(Channel c) {
    final result = db.nowNext(c, DateTime.now().toUtc());
    if (result.$1 == null) _wantGuide(c);
    return result;
  }

  // ----------------------------------------- guides fetched per channel

  /// Asks Xtream sources for what's on when their XMLTV guide has nothing
  /// for a channel. `null` turns it off (tests).
  final ChannelGuideFetcher? guideFetcher;

  final _guideAsked = <String, DateTime>{};
  final _guideQueue = <(SourceRecord, Channel)>[];
  int _guideRunning = 0;
  Timer? _guideArrived;

  /// Queues [c] for a per-channel fetch; called while rows are built, so
  /// what's on screen is asked for first and each channel at most every
  /// 15 minutes.
  void _wantGuide(Channel c) {
    if (guideFetcher == null) return;
    final key = ZaplineDatabase.channelKey(c);
    final now = DateTime.now();
    final last = _guideAsked[key];
    if (last != null && now.difference(last) < const Duration(minutes: 15)) {
      return;
    }
    final source = sources.where((s) => s.id == c.sourceId).firstOrNull;
    if (source == null || !ChannelGuideFetcher.supports(source)) return;
    _guideAsked[key] = now;
    _guideQueue.add((source, c));
    // Scrolled past: drop the oldest requests, they can be asked again.
    while (_guideQueue.length > 40) {
      final (_, old) = _guideQueue.removeAt(0);
      _guideAsked.remove(ZaplineDatabase.channelKey(old));
    }
    _pumpGuides();
  }

  void _pumpGuides() {
    final fetcher = guideFetcher!;
    while (_guideRunning < 4 && _guideQueue.isNotEmpty) {
      final (source, c) = _guideQueue.removeLast();
      _guideRunning++;
      fetcher
          .fetch(source, c)
          .then((n) {
            if (n > 0) _guideFetched();
          }, onError: (Object _) {})
          .whenComplete(() {
            _guideRunning--;
            _pumpGuides();
          });
    }
  }

  /// Redraws once for a burst of fetched channels.
  void _guideFetched() {
    _guideArrived ??= Timer(const Duration(milliseconds: 300), () {
      _guideArrived = null;
      version++;
      notifyListeners();
    });
  }

  final _likelyEpg = <String, (int, FreeEpg?)>{};

  /// The country a source's channels are mostly from, judged by prefixes
  /// such as "IT:", "IT |", "ITA" or a group called "Italia".
  FreeEpg? likelyFreeEpg(String sourceId) {
    final cached = _likelyEpg[sourceId];
    if (cached != null && cached.$1 == version) return cached.$2;
    final votes = <String, int>{};
    final all = db.channels(
      sourceId: sourceId,
      visibility: ChannelVisibility.all,
    );
    for (final c in all) {
      final code = _countryOf(c.groupTitle) ?? _countryOf(c.name);
      if (code != null) votes[code] = (votes[code] ?? 0) + 1;
    }
    FreeEpg? best;
    if (votes.isNotEmpty) {
      final top = votes.entries.reduce((a, b) => a.value >= b.value ? a : b);
      // A country counts once a fifth of the channels carry its tag.
      if (top.value * 5 >= all.length) {
        best = FreeEpg.countries.where((e) => e.code == top.key).firstOrNull;
      }
    }
    _likelyEpg[sourceId] = (version, best);
    return best;
  }

  static final _leadingTag = RegExp(r'^\W*([A-Za-z]{2,3})(?!\w)');
  static const _tagAliases = {
    'uk': 'gb',
    'ita': 'it',
    'ger': 'de',
    'deu': 'de',
    'fra': 'fr',
    'esp': 'es',
    'spa': 'es',
    'por': 'pt',
    'pol': 'pl',
    'tur': 'tr',
    'usa': 'us',
  };

  static String? _countryOf(String? text) {
    if (text == null) return null;
    final t = text.trim();
    final lower = t.toLowerCase();
    if (lower.startsWith('italia') || lower.startsWith('italy')) return 'it';
    final m = _leadingTag.firstMatch(t);
    if (m == null) return null;
    final tag = m.group(1)!;
    // Only upper-case tags: "Rai 1" or "Sky Uno" are not country codes.
    if (tag != tag.toUpperCase()) return null;
    final code = _tagAliases[tag.toLowerCase()] ?? tag.toLowerCase();
    return FreeEpg.countries.any((e) => e.code == code) ? code : null;
  }

  /// Whether [s] already uses a free EPG from the catalogue.
  bool hasFreeEpg(SourceRecord s) =>
      s.extraGuideUrls.any((u) => FreeEpg.ofUrl(u) != null);

  /// Adds [epg]'s guides to [s] and refreshes it so they load at once.
  Future<SyncResult> addFreeEpg(SourceRecord s, FreeEpg epg) {
    final record = s.copyWith(
      extraGuideUrls: [
        ...s.extraGuideUrls,
        for (final u in epg.urls)
          if (!s.extraGuideUrls.contains(u)) u,
      ],
    );
    updateSource(record);
    return refresh(sources.firstWhere((e) => e.id == s.id));
  }

  // ------------------------------------------------------------ reminders

  /// Programmes the user asked to be reminded of, by channel key and start.
  List<Reminder> get reminders {
    final raw = db.setting('reminders');
    if (raw == null) return const [];
    return [
      for (final r in jsonDecode(raw) as List)
        Reminder(
          channelKey: r['k'] as String,
          start: DateTime.fromMillisecondsSinceEpoch(
            (r['s'] as int) * 1000,
            isUtc: true,
          ),
          title: r['t'] as String,
        ),
    ];
  }

  void _saveReminders(List<Reminder> list) => db.setSetting(
    'reminders',
    jsonEncode([
      for (final r in list)
        {
          'k': r.channelKey,
          's': r.start.millisecondsSinceEpoch ~/ 1000,
          't': r.title,
        },
    ]),
  );

  bool hasReminder(Channel c, Programme p) => reminders.any(
    (r) => r.channelKey == ZaplineDatabase.channelKey(c) && r.start == p.start,
  );

  void toggleReminder(Channel c, Programme p) {
    final key = ZaplineDatabase.channelKey(c);
    final list = reminders;
    final i = list.indexWhere((r) => r.channelKey == key && r.start == p.start);
    _saveReminders([
      for (final (j, r) in list.indexed)
        if (j != i) r,
      if (i < 0) Reminder(channelKey: key, start: p.start, title: p.title),
    ]);
    notifyListeners();
  }

  /// Reminders whose programme starts within a minute (or started in the
  /// last ten); they are removed once returned. Old ones are dropped.
  List<(Reminder, Channel?)> takeDueReminders(DateTime now) {
    final list = reminders;
    if (list.isEmpty) return const [];
    final due = <Reminder>[], keep = <Reminder>[];
    for (final r in list) {
      final until = r.start.difference(now);
      if (until <= const Duration(minutes: 1)) {
        if (until > const Duration(minutes: -10)) due.add(r);
      } else {
        keep.add(r);
      }
    }
    if (due.isEmpty && keep.length == list.length) return const [];
    _saveReminders(keep);
    final all = due.isEmpty ? const <Channel>[] : channels();
    return [
      for (final r in due)
        (
          r,
          all
              .where((c) => ZaplineDatabase.channelKey(c) == r.channelKey)
              .firstOrNull,
        ),
    ];
  }

  // ------------------------------------------------------ films, series

  /// Opens films and series; `null` in tests that don't need it.
  final VodCatalog? vod;

  (int, _VodVisibility, _VodVisibility)? _vodCache;

  /// What each source's film and series filters leave out, and the
  /// categories still shown across sources; worked out once per change.
  (_VodVisibility, _VodVisibility) get _vodVisibility {
    final cached = _vodCache;
    if (cached != null && cached.$1 == version) return (cached.$2, cached.$3);
    _VodVisibility work(
      List<VodCategory> Function(String sourceId) categoriesOf,
      GroupFilter Function(SourceRecord) filterOf,
      Map<String, bool> Function(SourceRecord) choicesOf,
    ) {
      final hidden = <(String, String)>{};
      final shown = <String, int>{};
      for (final s in sources) {
        final filter = filterOf(s);
        final choices = choicesOf(s);
        for (final c in categoriesOf(s.id)) {
          if (choices[c.title] ??
              filter.hides(c.title.isEmpty ? null : c.title)) {
            hidden.add((s.id, c.title));
          } else {
            shown[c.title] = (shown[c.title] ?? 0) + c.count;
          }
        }
      }
      return (
        hidden: hidden,
        categories: [
          for (final e in shown.entries) (title: e.key, count: e.value),
        ],
      );
    }

    final movies = work(
      (id) => db.movieCategories(sourceId: id),
      (s) => s.movieFilter,
      (s) => s.movieChoices,
    );
    final shows = work(
      (id) => db.showCategories(sourceId: id),
      (s) => s.showFilter,
      (s) => s.showChoices,
    );
    _vodCache = (version, movies, shows);
    return (movies, shows);
  }

  List<VodCategory> movieCategories() => _vodVisibility.$1.categories;

  List<VodCategory> showCategories() => _vodVisibility.$2.categories;

  /// Categories a filter would leave of [sourceId]'s films or series, and
  /// their titles: (categories shown, all categories, titles shown).
  (int, int, int) previewVodFilter(
    String sourceId,
    GroupFilter filter, {
    required bool movies,
  }) {
    final all = movies
        ? db.movieCategories(sourceId: sourceId)
        : db.showCategories(sourceId: sourceId);
    var shown = 0, titles = 0;
    for (final c in all) {
      if (filter.hides(c.title.isEmpty ? null : c.title)) continue;
      shown++;
      titles += c.count;
    }
    return (shown, all.length, titles);
  }

  List<Movie> movies({
    String? category,
    bool newest = false,
    int limit = 1 << 30,
    int offset = 0,
  }) => db.movies(
    category: category,
    hiddenCategories: _vodVisibility.$1.hidden,
    newest: newest,
    limit: limit,
    offset: offset,
  );

  List<Show> shows({
    String? category,
    bool newest = false,
    int limit = 1 << 30,
    int offset = 0,
  }) => db.shows(
    category: category,
    hiddenCategories: _vodVisibility.$2.hidden,
    newest: newest,
    limit: limit,
    offset: offset,
  );

  List<Movie> searchMovies(String q) => db.searchMovies(q);
  List<Show> searchShows(String q) => db.searchShows(q);

  SourceRecord? _source(String id) =>
      sources.where((s) => s.id == id).firstOrNull;

  Future<MovieDetails?> movieDetails(Movie m) async {
    final source = _source(m.sourceId);
    if (source == null || vod == null) return null;
    return vod!.movieDetails(source, m);
  }

  Future<ShowDetails> showDetails(Show s) async {
    final source = _source(s.sourceId);
    if (source == null || vod == null) {
      return ShowDetails(episodes: db.playlistEpisodes(s.sourceId, s.id));
    }
    return vod!.showDetails(source, s);
  }

  Uri? movieUrl(Movie m, [MovieDetails? details]) {
    final source = _source(m.sourceId);
    if (source == null || vod == null) return m.streamUrl;
    return vod!.movieUrl(source, m, details: details);
  }

  Uri? episodeUrl(Show s, Episode e) {
    final source = _source(s.sourceId);
    if (source == null || vod == null) return e.streamUrl;
    return vod!.episodeUrl(source, e);
  }

  PlaybackPosition? positionOf(String key) => db.position(key);

  /// Saves where playback stopped; screens redraw when the player closes.
  void savePosition(String key, Duration position, Duration duration) {
    if (duration <= Duration.zero) return;
    db.savePosition(key, position, duration);
  }

  /// Called when the player closes so rows like "Continue watching" update.
  void positionsChanged() => notifyListeners();

  /// Positions of a series' episodes, by episode id.
  Map<String, PlaybackPosition> episodePositions(Show s) => {
    for (final p in db.positions(prefix: 'episode:${s.sourceId}/${s.id}/'))
      p.key.substring(p.key.lastIndexOf('/') + 1): p,
  };

  /// Films and series started and not finished, most recent first; for a
  /// series, its latest episode.
  List<ContinueItem> continueWatching({int limit = 20}) {
    final out = <ContinueItem>[];
    final seenShows = <String>{};
    for (final p in db.positions(limit: 200)) {
      if (out.length >= limit) break;
      final key = p.key;
      if (key.startsWith('movie:')) {
        if (!p.resumable) continue;
        final (src, id) = _split(key.substring(6));
        final m = db.movie(src, id);
        if (m != null) out.add(ContinueItem(position: p, movie: m));
      } else if (key.startsWith('episode:')) {
        final rest = key.substring(8);
        final parts = rest.split('/');
        if (parts.length < 3) continue;
        final showKey = '${parts[0]}/${parts[1]}';
        if (!seenShows.add(showKey)) continue;
        final show = db.show(parts[0], parts[1]);
        if (show != null) {
          out.add(ContinueItem(position: p, show: show, episodeId: parts.last));
        }
      }
    }
    return out;
  }

  static (String, String) _split(String sourceAndId) {
    final i = sourceAndId.indexOf('/');
    return (sourceAndId.substring(0, i), sourceAndId.substring(i + 1));
  }

  bool inMyList(String key) => db.inMyList(key);

  void toggleMyList(String key) {
    db.setInMyList(key, !db.inMyList(key));
    notifyListeners();
  }

  List<Movie> myMovies() => [
    for (final (src, id) in _myList('movie:')) ?db.movie(src, id),
  ];

  List<Show> myShows() => [
    for (final (src, id) in _myList('show:')) ?db.show(src, id),
  ];

  Iterable<(String, String)> _myList(String prefix) => db
      .myList()
      .where((k) => k.startsWith(prefix))
      .map((k) => _split(k.substring(prefix.length)));

  /// What the last sync got from [sourceId]'s TV guides.
  GuideStatus? guideStatus(String sourceId) {
    final raw = db.setting('guideStatus:$sourceId');
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, Object?>;
    return GuideStatus(
      programmes: j['programmes'] as int? ?? 0,
      errors: [for (final e in j['errors'] as List? ?? const []) '$e'],
      perChannel: ChannelGuideFetcher.supports(
        sources.firstWhere(
          (s) => s.id == sourceId,
          orElse: () => const SourceRecord(
            id: '',
            kind: SourceKind.m3u,
            name: '',
            url: '',
          ),
        ),
      ),
    );
  }

  Map<String, List<Programme>> guide(
    List<Channel> channels,
    DateTime from,
    DateTime to,
  ) => db.guide(channels, from, to);

  GuideCoverage coverage(String sourceId) =>
      db.guideCoverage(sourceId: sourceId);

  /// Saves and synchronises a new source. On failure nothing is kept and the
  /// error is rethrown for display.
  Future<SyncResult> addSource(SourceInput input) async {
    final record = input.toRecord(_newId());
    if (_isDuplicate(record)) {
      throw Exception('This source is already added');
    }
    final result = await _addRecord(record);
    _epgSuggestion = record.id;
    return result;
  }

  String? _epgSuggestion;

  /// A source just added whose guide covers less than 80% of its
  /// channels and that uses no free EPG yet: worth offering one, once.
  SourceRecord? takeEpgSuggestion() {
    final id = _epgSuggestion;
    _epgSuggestion = null;
    final s = sources.where((e) => e.id == id).firstOrNull;
    if (s == null || hasFreeEpg(s)) return null;
    final cov = coverage(s.id);
    return cov.channels > 0 && cov.ratio < 0.8 ? s : null;
  }

  static int _idCounter = 0;
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${(_idCounter++).toRadixString(36)}';

  bool _isDuplicate(SourceRecord r) => sources.any(
    (s) => s.kind == r.kind && s.url == r.url && s.username == r.username,
  );

  Future<SyncResult> _addRecord(SourceRecord record) async {
    await _storeSource(record);
    try {
      return await _sync(record);
    } catch (_) {
      deleteSource(record.id);
      rethrow;
    }
  }

  /// Saves [record], keeping its password in the keystore when possible.
  Future<void> _storeSource(SourceRecord record) async {
    var stored = record;
    if (record.password.isNotEmpty && _keystoreWorks) {
      try {
        await secrets.write(_secretKey(record.id), record.password);
        _passwords[record.id] = record.password;
        stored = record.copyWith(password: '');
      } catch (e) {
        _keystoreWorks = false;
        debugPrint('Keystore unavailable, password stays local: $e');
      }
    }
    db.saveSource(stored);
  }

  // ------------------------------------------------------------- backup

  /// The user's setup as JSON, passwords included.
  String exportBackup() =>
      Backup.export(db, passwordOf: (s) => _passwords[s.id] ?? s.password);

  /// Adds the backup's sources (skipping ones already present), downloads
  /// them, then restores favourites and manual guide links. Returns a
  /// summary for display; sources that fail to connect are reported, not
  /// fatal.
  Future<String> restoreBackup(String json) async {
    final contents = Backup.parse(json);
    final ids = <int, String>{};
    var added = 0, skipped = 0;
    final failed = <String>[];
    for (final (i, s) in contents.sources.indexed) {
      final existing = sources
          .where(
            (e) =>
                e.kind == s.kind && e.url == s.url && e.username == s.username,
          )
          .firstOrNull;
      if (existing != null) {
        ids[i] = existing.id;
        skipped++;
        continue;
      }
      final record = SourceRecord(
        id: _newId(),
        kind: s.kind,
        name: s.name,
        url: s.url,
        username: s.username,
        password: s.password,
        extraGuideUrls: s.extraGuideUrls,
      );
      try {
        await _addRecord(record);
        ids[i] = record.id;
        added++;
      } catch (e) {
        failed.add('${s.name} ($e)');
      }
    }
    for (final (i, channel) in contents.favourites) {
      final id = ids[i];
      if (id != null) db.addFavouriteKey('$id/$channel');
    }
    for (final (i, channel, guide) in contents.guideOverrides) {
      final id = ids[i];
      if (id != null) db.setGuideOverrideKey('$id/$channel', guide);
    }
    db.rebuildGuideLinks();
    _reload();
    notifyListeners();
    return [
      '$added sources restored',
      if (skipped > 0) '$skipped already present',
      if (failed.isNotEmpty) 'could not connect to ${failed.join(', ')}',
    ].join(', ');
  }

  Future<SyncResult> refresh(SourceRecord source) => _sync(source);

  /// Re-syncs sources not refreshed within [maxAge]; errors are ignored so a
  /// temporarily unreachable server never blocks startup.
  Future<void> refreshStale({Duration? maxAge}) async {
    final hours = settings.refreshHours;
    if (maxAge == null && hours == 0) return; // automatic refresh is off
    maxAge ??= Duration(hours: hours);
    final cutoff = DateTime.now().toUtc().subtract(maxAge);
    for (final s in List.of(sources)) {
      if (s.syncedAt != null && s.syncedAt!.isAfter(cutoff)) continue;
      try {
        await _sync(s);
      } catch (e) {
        debugPrint('Background refresh of ${s.name} failed: $e');
      }
    }
  }

  void deleteSource(String id) {
    _passwords.remove(id);
    secrets.delete(_secretKey(id)).catchError((Object _) {});
    db.deleteSource(id);
    db.rebuildGuideLinks();
    _reload();
    notifyListeners();
  }

  Future<SyncResult> _sync(SourceRecord s) async {
    await _secretsLoading;
    // Re-read: the password may have arrived from the keystore meanwhile.
    s = sources.where((e) => e.id == s.id).firstOrNull ?? s;
    syncingSourceId = s.id;
    progress = const SyncProgress(SyncStage.channels);
    notifyListeners();
    try {
      final result = await syncRunner(s, (p) {
        progress = p;
        notifyListeners();
      });
      db.setSetting(
        'guideStatus:${s.id}',
        jsonEncode({
          'programmes': result.guide.programmes,
          'errors': result.guideErrors,
        }),
      );
      // A new sync may have brought a guide: ask again where it didn't.
      _guideAsked.clear();
      return result;
    } finally {
      syncingSourceId = null;
      progress = null;
      _reload();
      notifyListeners();
    }
  }
}

/// Outcome of the TV guide part of a source's last sync.
class GuideStatus {
  const GuideStatus({
    required this.programmes,
    required this.errors,
    required this.perChannel,
  });

  /// Programmes imported from the XMLTV guides.
  final int programmes;

  /// Guides that could not be downloaded or read, with the reason.
  final List<String> errors;

  /// The source can be asked for what's on channel by channel instead.
  final bool perChannel;
}

/// A programme to be reminded of when it starts.
class Reminder {
  const Reminder({
    required this.channelKey,
    required this.start,
    required this.title,
  });

  final String channelKey;
  final DateTime start;
  final String title;
}

/// A film or series episode to resume.
class ContinueItem {
  const ContinueItem({
    required this.position,
    this.movie,
    this.show,
    this.episodeId,
  });

  final PlaybackPosition position;
  final Movie? movie;
  final Show? show;
  final String? episodeId;
}

typedef _VodVisibility = ({
  Set<(String, String)> hidden,
  List<VodCategory> categories,
});

/// Channels, films or series: what a filter or category applies to.
enum ContentKind { tv, movies, shows }

/// A channel group or a film or series category, as the filters see it.
class CategoryInfo {
  const CategoryInfo({
    required this.title,
    required this.count,
    required this.hidden,
    required this.explicit,
    required this.locked,
  });

  final String title;

  /// Channels or titles in it.
  final int count;
  final bool hidden;

  /// Shown or hidden by hand; `null` when the filter decides.
  final bool? explicit;

  /// Asks for the PIN (channel groups only).
  final bool locked;
}

/// Filters and choices as they were, for "Undo".
class CategorySnapshot {
  const CategorySnapshot({
    required this.sourceId,
    required this.kind,
    required this.filter,
    required this.choices,
  });

  final String sourceId;
  final ContentKind kind;
  final GroupFilter filter;
  final Map<String, bool?> choices;
}
