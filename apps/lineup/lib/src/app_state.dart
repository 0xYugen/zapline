import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:lineup_core/lineup_core.dart';
import 'package:lineup_data/lineup_data.dart';

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
SyncRunner isolateSyncRunner(String dbPath) => (source, onProgress) async {
  final port = ReceivePort();
  final send = port.sendPort;
  final sub = port.listen((m) => onProgress(m as SyncProgress));
  try {
    return await _syncInIsolate(dbPath, source, send);
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
) => Isolate.run(() async {
  final db = LineupDatabase.open(dbPath);
  try {
    return await SourceSync(db).sync(source, onProgress: progress.send);
  } finally {
    db.close();
  }
});

/// App-wide state backed by the local database.
class AppState extends ChangeNotifier {
  AppState(this.db, {required this.syncRunner}) {
    _reload();
  }

  final LineupDatabase db;
  final SyncRunner syncRunner;

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
    sources = db.sources();
    groups = db.groups();
    channelCount = db.channelCount();
    _favouriteKeys = db.favouriteKeys();
  }

  List<Channel> channels({String? group}) => db.channels(group: group);

  List<Channel> search(String query) => db.search(query);

  List<Channel> favourites() => db.favourites();

  bool get hasFavourites => _favouriteKeys.isNotEmpty;

  bool isFavourite(Channel c) =>
      _favouriteKeys.contains(LineupDatabase.channelKey(c));

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

  (Programme?, Programme?) nowNext(Channel c) =>
      db.nowNext(c, DateTime.now().toUtc());

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
    final record = input.toRecord(
      DateTime.now().microsecondsSinceEpoch.toRadixString(36),
    );
    final duplicate = sources.any(
      (s) =>
          s.kind == record.kind &&
          s.url == record.url &&
          s.username == record.username,
    );
    if (duplicate) throw Exception('This source is already added');
    db.saveSource(record);
    try {
      return await _sync(record);
    } catch (_) {
      db.deleteSource(record.id);
      _reload();
      notifyListeners();
      rethrow;
    }
  }

  Future<SyncResult> refresh(SourceRecord source) => _sync(source);

  /// Re-syncs sources not refreshed within [maxAge]; errors are ignored so a
  /// temporarily unreachable server never blocks startup.
  Future<void> refreshStale({
    Duration maxAge = const Duration(hours: 12),
  }) async {
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
    db.deleteSource(id);
    db.rebuildGuideLinks();
    _reload();
    notifyListeners();
  }

  Future<SyncResult> _sync(SourceRecord s) async {
    syncingSourceId = s.id;
    progress = const SyncProgress(SyncStage.channels);
    notifyListeners();
    try {
      return await syncRunner(s, (p) {
        progress = p;
        notifyListeners();
      });
    } finally {
      syncingSourceId = null;
      progress = null;
      _reload();
      notifyListeners();
    }
  }
}
