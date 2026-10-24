import 'dart:async';
import 'dart:io' show gzip;

import 'package:http/http.dart' as http;
import 'package:zapline_core/zapline_core.dart';

import 'database.dart';
import 'source_record.dart';

enum SyncStage { channels, guide, linking, done }

class SyncProgress {
  const SyncProgress(this.stage, {this.count = 0, this.message});

  final SyncStage stage;

  /// Items processed so far in [stage] (channels, then programmes).
  final int count;
  final String? message;

  @override
  String toString() => '${stage.name} $count ${message ?? ''}'.trim();
}

class SyncResult {
  const SyncResult({
    required this.channels,
    required this.guide,
    required this.coverage,
    this.guideErrors = const [],
  });

  final int channels;
  final GuideImportResult guide;
  final GuideCoverage coverage;

  /// Guides that failed to download or parse; channels still synced.
  final List<String> guideErrors;
}

class SyncException implements Exception {
  SyncException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Downloads a source's channels and guides into a [ZaplineDatabase].
///
/// Guides are kept for [guidePast] back and [guideAhead] forward; anything
/// outside that window is dropped while parsing, so even very large XMLTV
/// files stay within a bounded memory and disk budget.
class SourceSync {
  SourceSync(
    this.db, {
    http.Client? httpClient,
    this.guidePast = const Duration(days: 1),
    this.guideAhead = const Duration(days: 7),
  }) : _http = httpClient ?? http.Client();

  final ZaplineDatabase db;
  final Duration guidePast;
  final Duration guideAhead;
  final http.Client _http;

  static const userAgent = XtreamClient.defaultUserAgent;

  Future<SyncResult> sync(
    SourceRecord source, {
    bool includeGuide = true,
    void Function(SyncProgress)? onProgress,
  }) async {
    onProgress?.call(const SyncProgress(SyncStage.channels));
    final (channels, guideUrls, offset) = switch (source.kind) {
      SourceKind.xtream => await _xtream(source),
      SourceKind.m3u => await _m3u(source),
      SourceKind.stalker => throw SyncException(
        'Stalker portals are not supported yet',
      ),
    };
    db.replaceChannels(source.id, channels);
    db.applyGroupVisibility(source.id, source.groupFilter);
    onProgress?.call(SyncProgress(SyncStage.channels, count: channels.length));

    var guide = const GuideImportResult(channels: 0, programmes: 0);
    final errors = <String>[];
    if (includeGuide) {
      final now = DateTime.now().toUtc();
      final urls = {...guideUrls, ...source.extraGuideUrls.map(Uri.parse)};
      for (final url in urls) {
        try {
          final r = await _importGuide(
            url,
            now,
            onProgress,
            guide.programmes,
            source.guideOffset,
          );
          guide = GuideImportResult(
            channels: guide.channels + r.channels,
            programmes: guide.programmes + r.programmes,
          );
        } catch (e) {
          errors.add('${url.host}: $e');
        }
      }
      db.pruneProgrammes(now.subtract(guidePast));
    }

    onProgress?.call(const SyncProgress(SyncStage.linking));
    final coverage = db.rebuildGuideLinks();
    db.markSynced(source.id, DateTime.now().toUtc(), serverOffset: offset);
    onProgress?.call(SyncProgress(SyncStage.done, count: coverage.matched));
    return SyncResult(
      channels: channels.length,
      guide: guide,
      coverage: coverage,
      guideErrors: errors,
    );
  }

  Future<(List<Channel>, List<Uri>, Duration?)> _xtream(SourceRecord s) async {
    final client = XtreamClient(credentialsOf(s), httpClient: _http);
    final XtreamAccount account;
    try {
      account = await client.authenticate();
    } on XtreamException catch (e) {
      throw SyncException(e.message);
    }
    if (!account.isActive) {
      throw SyncException('Account status: ${account.status}');
    }
    final categories = {
      for (final c in await client.liveCategories()) c.id: c.name,
    };
    final ext = account.preferredLiveExtension;
    final channels = [
      for (final st in await client.liveStreams())
        if (st.streamId >= 0)
          Channel(
            sourceId: s.id,
            id: '${st.streamId}',
            name: st.name,
            number: st.number,
            streamUrl: client.liveUrl(st.streamId, extension: ext),
            groupTitle: categories[st.categoryId],
            logoUrl: (st.iconUrl == null || st.iconUrl!.isEmpty)
                ? null
                : Uri.tryParse(st.iconUrl!),
            epgChannelId: st.epgChannelId,
            catchup: st.hasArchive
                ? CatchupInfo(mode: CatchupMode.xtream, days: st.archiveDays)
                : null,
            httpHeaders: const {'User-Agent': userAgent},
          ),
    ];
    return (channels, [client.xmltvUrl], account.serverUtcOffset);
  }

  /// Where and how to log in to an Xtream source.
  static XtreamCredentials credentialsOf(SourceRecord s) {
    final u = Uri.parse(s.url.contains('://') ? s.url : 'http://${s.url}');
    return XtreamCredentials(
      baseUrl: Uri(
        scheme: u.scheme,
        host: u.host,
        port: u.hasPort ? u.port : null,
      ),
      username: s.username,
      password: s.password,
    );
  }

  Future<(List<Channel>, List<Uri>, Duration?)> _m3u(SourceRecord s) async {
    final uri = Uri.tryParse(s.url);
    if (uri == null || !uri.hasScheme) throw SyncException('Not a valid URL');
    final res = await _send(uri);
    final parser = M3uParser();
    final channels = <Channel>[];
    var i = 0;
    await for (final e in parser.parseBytes(res.stream)) {
      final stream = Uri.tryParse(e.url);
      if (stream == null) continue;
      i++;
      channels.add(
        Channel(
          sourceId: s.id,
          id: '$i',
          name: e.title,
          number: e.tvgChno ?? i,
          streamUrl: stream,
          groupTitle: e.group,
          logoUrl: e.tvgLogo == null ? null : Uri.tryParse(e.tvgLogo!),
          epgChannelId: e.tvgId,
          catchup: _m3uCatchup(e),
          httpHeaders: e.httpHeaders,
        ),
      );
    }
    if (channels.isEmpty) {
      throw SyncException('The playlist contains no channels');
    }
    return (channels, parser.header.epgUrls, null);
  }

  static CatchupInfo? _m3uCatchup(M3uEntry e) {
    final mode = switch (e.catchup?.toLowerCase()) {
      null => null,
      'default' => CatchupMode.defaultMode,
      'append' => CatchupMode.append,
      'shift' || 'timeshift' => CatchupMode.shift,
      'flussonic' ||
      'flussonic-hls' ||
      'flussonic-ts' ||
      'fs' => CatchupMode.flussonic,
      'xc' => CatchupMode.xtream,
      'vod' => CatchupMode.vod,
      _ => null,
    };
    if (mode == null) return null;
    return CatchupInfo(
      mode: mode,
      days: e.catchupDays,
      source: e.catchupSource,
    );
  }

  Future<GuideImportResult> _importGuide(
    Uri url,
    DateTime now,
    void Function(SyncProgress)? onProgress,
    int offset,
    Duration shift,
  ) async {
    onProgress?.call(
      SyncProgress(SyncStage.guide, count: offset, message: url.host),
    );
    final res = await _send(url);
    var count = offset;
    final items =
        XmltvParser(
          // Widen the window by the shift so no programme is lost to it.
          from: now.subtract(guidePast).subtract(shift),
          to: now.add(guideAhead).subtract(shift),
        ).parseBytes(_maybeGunzip(res.stream)).map((item) {
          if (item is! XmltvProgramme) return item;
          if (++count % 2000 == 0) {
            onProgress?.call(
              SyncProgress(SyncStage.guide, count: count, message: url.host),
            );
          }
          return shift == Duration.zero
              ? item
              : XmltvProgramme(item.programme.shifted(shift));
        });
    return db.importGuide(items);
  }

  Future<http.StreamedResponse> _send(Uri uri) async {
    final res = await _http.send(
      http.Request('GET', uri)..headers['User-Agent'] = userAgent,
    );
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw SyncException('HTTP ${res.statusCode} from ${uri.host}');
    }
    return res;
  }

  /// Guides are often served as `.xml.gz`, sometimes without a matching
  /// Content-Encoding, so detect gzip by its magic bytes instead.
  ///
  /// Written as async generators so pausing the consumer (a slow parser on
  /// a low-end device) pauses the download instead of buffering it.
  static Stream<List<int>> _maybeGunzip(Stream<List<int>> bytes) async* {
    final it = StreamIterator(bytes);
    List<int>? first;
    while (await it.moveNext()) {
      if (it.current.isNotEmpty) {
        first = it.current;
        break;
      }
    }
    if (first == null) return;
    final head = first;

    Stream<List<int>> all() async* {
      yield head;
      while (await it.moveNext()) {
        yield it.current;
      }
    }

    final isGzip = head.length >= 2 && head[0] == 0x1f && head[1] == 0x8b;
    yield* isGzip ? gzip.decoder.bind(all()) : all();
  }
}
