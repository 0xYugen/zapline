import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

import 'secret_store.dart';
import 'format.dart';
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
  }) : secrets = secrets ?? MemorySecretStore() {
    _reload();
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

  bool get isEmpty => channelCount == 0;
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
      db.channels(group: group, visibility: _visibility);

  List<Channel> search(String query) =>
      db.search(query, visibility: _visibility);

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
    return _addRecord(record);
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
