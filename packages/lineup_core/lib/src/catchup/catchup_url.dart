import '../models/channel.dart';
import '../xtream/xtream_url.dart';

/// Builds the URL that replays [start]–[stop] of [channel] from the
/// provider's archive, or returns `null` when the channel has no usable
/// catch-up.
///
/// Semantics follow the de-facto standard set by Kodi's IPTV Simple client:
///
/// * `xtream`/`xc`: `/timeshift/U/P/{minutes}/{YYYY-MM-DD:HH-MM}/{id}.ts`
///   (or `.m3u8` when the live stream is HLS),
///   with the start expressed in the panel's local time ([serverOffset]).
/// * `default`: `catchup-source` is a complete URL template.
/// * `append`: `catchup-source` is appended to the live URL.
/// * `shift`: `utc` and `lutc` query parameters are added to the live URL.
/// * `flussonic`: the live path is rewritten to Flussonic's archive form.
///
/// Templates understand `{utc}`, `${start}`, `{utcend}`, `${end}`, `{lutc}`,
/// `${now}`, `${timestamp}`, `{duration}`, `${duration}`, `{duration:N}`,
/// `{offset:N}`, `{Y} {m} {d} {H} {M} {S}` (UTC start) and `{catchup-id}`.
Uri? buildCatchupUrl(
  Channel channel, {
  required DateTime start,
  required DateTime stop,
  DateTime? now,
  Duration serverOffset = Duration.zero,
  String? catchupId,
}) {
  final info = channel.catchup;
  if (info == null) return null;
  final live = channel.streamUrl;
  final at = (now ?? DateTime.now()).toUtc();
  final s = start.toUtc();
  final e = stop.toUtc();

  String fill(String template) => _fillTemplate(
        template,
        start: s,
        stop: e,
        now: at,
        catchupId: catchupId,
      );

  switch (info.mode) {
    case CatchupMode.xtream:
      return _xtream(channel, s, e, serverOffset);
    case CatchupMode.defaultMode:
      final src = info.source;
      if (src == null || src.isEmpty) return null;
      return Uri.tryParse(fill(src));
    case CatchupMode.append:
      final src = info.source;
      if (src == null || src.isEmpty) return null;
      return Uri.tryParse('$live${fill(src)}');
    case CatchupMode.shift:
      return live.replace(
        queryParameters: {
          ...live.queryParameters,
          'utc': '${_secs(s)}',
          'lutc': '${_secs(at)}',
        },
      );
    case CatchupMode.flussonic:
      return _flussonic(live, s, e);
    case CatchupMode.vod:
      final src = info.source;
      return src == null || src.isEmpty ? live : Uri.tryParse(fill(src));
  }
}

/// Whether [p] can be replayed: it has started and lies within the archive.
bool canReplay(Channel channel, Programme p, {DateTime? now}) {
  final info = channel.catchup;
  if (info == null) return false;
  final at = (now ?? DateTime.now()).toUtc();
  if (!p.start.isBefore(at)) return false;
  final days = info.days;
  if (days == null || days <= 0) return true;
  return p.start.isAfter(at.subtract(Duration(days: days)));
}

int _secs(DateTime t) => t.millisecondsSinceEpoch ~/ 1000;

Uri? _xtream(Channel c, DateTime s, DateTime e, Duration serverOffset) {
  final creds = detectXtreamCredentials(c.streamUrl.toString());
  if (creds == null) return null;
  final local = s.add(serverOffset);
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp = '${local.year}-${two(local.month)}-${two(local.day)}:'
      '${two(local.hour)}-${two(local.minute)}';
  final minutes = e.difference(s).inMinutes;
  final file = c.streamUrl.pathSegments.last;
  final id = file.split('.').first;
  // Keep the live container: HLS-only panels serve archives as HLS too.
  final ext = file.endsWith('.m3u8') ? 'm3u8' : 'ts';
  return creds.baseUrl.replace(
    path: '/timeshift/${Uri.encodeComponent(creds.username)}/'
        '${Uri.encodeComponent(creds.password)}/$minutes/$stamp/$id.$ext',
  );
}

/// `…/channel/mpegts` → `…/channel/timeshift_abs-START.ts`,
/// `…/channel/index.m3u8` → `…/channel/index-START-DURATION.m3u8`.
Uri? _flussonic(Uri live, DateTime s, DateTime e) {
  final segs = [...live.pathSegments];
  if (segs.isEmpty) return null;
  final last = segs.removeLast();
  final dur = e.difference(s).inSeconds;
  final String replacement;
  if (last.endsWith('.m3u8')) {
    final name = last.substring(0, last.length - 5);
    replacement = '$name-${_secs(s)}-$dur.m3u8';
  } else if (last == 'mpegts' || last.endsWith('.ts')) {
    replacement = 'timeshift_abs-${_secs(s)}.ts';
  } else {
    return null;
  }
  return live.replace(pathSegments: [...segs, replacement]);
}

String _fillTemplate(
  String t, {
  required DateTime start,
  required DateTime stop,
  required DateTime now,
  String? catchupId,
}) {
  final dur = stop.difference(start).inSeconds;
  final offset = now.difference(start).inSeconds;
  String two(int n) => n.toString().padLeft(2, '0');
  final simple = <String, String>{
    '{utc}': '${_secs(start)}',
    r'${start}': '${_secs(start)}',
    '{utcend}': '${_secs(stop)}',
    r'${end}': '${_secs(stop)}',
    '{lutc}': '${_secs(now)}',
    r'${now}': '${_secs(now)}',
    r'${timestamp}': '${_secs(now)}',
    '{duration}': '$dur',
    r'${duration}': '$dur',
    r'${offset}': '$offset',
    '{Y}': '${start.year}',
    '{m}': two(start.month),
    '{d}': two(start.day),
    '{H}': two(start.hour),
    '{M}': two(start.minute),
    '{S}': two(start.second),
    '{catchup-id}': catchupId ?? '',
  };
  var out = t;
  simple.forEach((k, v) => out = out.replaceAll(k, v));
  out = out.replaceAllMapped(
    RegExp(r'\{(duration|offset):(\d+)\}'),
    (m) {
      final div = int.parse(m.group(2)!);
      final value = m.group(1) == 'duration' ? dur : offset;
      return div == 0 ? '$value' : '${value ~/ div}';
    },
  );
  return out;
}
