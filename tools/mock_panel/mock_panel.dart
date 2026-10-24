// Development server that imitates an Xtream-compatible panel.
//
//   dart run tools/mock_panel/mock_panel.dart [port]
//
// Login: username `demo`, password `demo`. Channel streams redirect to public
// HLS test streams published by Apple, Mux and Akamai for player testing.
// The guide is generated around the current time.
//
// From the Android emulator the host is reachable at http://10.0.2.2:<port>.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

const _user = 'demo';
const _pass = 'demo';

const _channels = [
  (
    1,
    'Big Buck Bunny',
    '1',
    'bbb.test',
    'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8'
  ),
  (
    2,
    'Bip Bop 4:3',
    '1',
    'bipbop.test',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/bipbop_4x3_variant.m3u8'
  ),
  (
    3,
    'Bip Bop Advanced',
    '1',
    'bipbopadv.test',
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8'
  ),
  (
    4,
    'Live Test Clock',
    '2',
    'live.test',
    'https://demo.unified-streaming.com/k8s/live/stable/live.isml/.m3u8'
  ),
  (
    5,
    'Tears of Steel',
    '2',
    'tos.test',
    'https://test-streams.mux.dev/tos_ismc/main.m3u8'
  ),
  (6, 'Broken Stream', '2', 'broken.test', 'http://127.0.0.1:9/nothing.ts'),
  // No guide id and a name the matcher cannot link: for manual mapping.
  (
    7,
    'Cinema One HD',
    '2',
    '',
    'https://test-streams.mux.dev/tos_ismc/main.m3u8',
  ),
];

const _categories = {'1': 'Test Patterns', '2': 'Demo Channels'};

Future<void> main(List<String> args) async {
  final port = args.isEmpty ? 8099 : int.parse(args.first);
  final server = await HttpServer.bind(InternetAddress.anyIPv4, port);
  stdout
      .writeln('Mock panel on http://localhost:$port  (user/pass: demo/demo)');
  stdout.writeln(
      'M3U: http://localhost:$port/get.php?username=demo&password=demo&type=m3u_plus');
  await for (final req in server) {
    try {
      await _handle(req);
    } catch (e) {
      req.response.statusCode = 500;
      req.response.write('$e');
    }
    await req.response.close();
    stdout.writeln('${req.response.statusCode} ${req.method} ${req.uri}');
  }
}

Future<void> _handle(HttpRequest req) async {
  final q = req.uri.queryParameters;
  final path = req.uri.path;
  final res = req.response;
  final authed = q['username'] == _user && q['password'] == _pass;

  if (path == '/player_api.php') {
    res.headers.contentType = ContentType.json;
    if (!authed) {
      res.write(jsonEncode({
        'user_info': {'auth': 0}
      }));
      return;
    }
    res.write(jsonEncode(_api(q['action'], q, req)));
    return;
  }

  if (path == '/get.php' && authed) {
    final base = _base(req);
    res.headers.contentType = ContentType('audio', 'x-mpegurl');
    final b = StringBuffer(
        '#EXTM3U url-tvg="$base/xmltv.php?username=$_user&password=$_pass"\n');
    for (final c in _channels) {
      b.writeln('#EXTINF:-1 tvg-id="${c.$4}" tvg-name="${c.$2}" '
          'group-title="${_categories[c.$3]}",${c.$2}');
      b.writeln('$base/live/$_user/$_pass/${c.$1}.ts');
    }
    res.write(b);
    return;
  }

  if (path == '/xmltv.php' && authed) {
    res.headers.contentType =
        ContentType('application', 'xml', charset: 'utf-8');
    res.write(_xmltv());
    return;
  }

  // Catch-up: /timeshift/U/P/{minutes}/{YYYY-MM-DD:HH-MM}/{id}.{ext}. Any
  // archived programme replays a public VOD test stream.
  final shift = RegExp(
    r'^/timeshift/([^/]+)/([^/]+)/(\d+)/(\d{4}-\d{2}-\d{2}:\d{2}-\d{2})/(\d+)\.\w+$',
  ).firstMatch(path);
  if (shift != null) {
    if (shift.group(1) != _user || shift.group(2) != _pass) {
      res.statusCode = HttpStatus.forbidden;
      return;
    }
    stdout.writeln('  catch-up ${shift.group(4)} for ${shift.group(3)} min');
    res.statusCode = HttpStatus.found;
    res.headers.set(
      HttpHeaders.locationHeader,
      'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
    );
    return;
  }

  final logo = RegExp(r'^/logo/(\d+)\.png$').firstMatch(path);
  if (logo != null) {
    final id = int.parse(logo.group(1)!);
    if (id > _channels.length) {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    res.headers.contentType = ContentType('image', 'png');
    res.add(_png(120, 80, _logoColors[(id - 1) % _logoColors.length]));
    return;
  }

  final live = RegExp(r'^/live/([^/]+)/([^/]+)/(\d+)\.\w+$').firstMatch(path);
  if (live != null) {
    if (live.group(1) != _user || live.group(2) != _pass) {
      res.statusCode = HttpStatus.forbidden;
      return;
    }
    final id = int.parse(live.group(3)!);
    final ch = _channels.where((c) => c.$1 == id).firstOrNull;
    if (ch == null) {
      res.statusCode = HttpStatus.notFound;
      return;
    }
    res.statusCode = HttpStatus.found;
    res.headers.set(HttpHeaders.locationHeader, ch.$5);
    return;
  }

  res.statusCode = authed ? HttpStatus.notFound : HttpStatus.unauthorized;
}

Object? _api(String? action, Map<String, String> q, HttpRequest req) {
  final now = DateTime.now().toUtc();
  switch (action) {
    case null:
      return {
        'user_info': {
          'username': _user,
          'auth': 1,
          'status': 'Active',
          // Deliberately a string, as many panels send it.
          'exp_date':
              '${now.add(const Duration(days: 365)).millisecondsSinceEpoch ~/ 1000}',
          'is_trial': '0',
          'active_cons': '0',
          'max_connections': '2',
          'allowed_output_formats': ['m3u8'], // HLS-only panel
        },
        'server_info': {
          'url': req.requestedUri.host,
          'port': '${req.requestedUri.port}',
          'https_port': '443',
          'server_protocol': 'http',
          'timezone': 'UTC',
          'timestamp_now': now.millisecondsSinceEpoch ~/ 1000,
          'time_now':
              now.toIso8601String().substring(0, 19).replaceFirst('T', ' '),
        },
      };
    case 'get_live_categories':
      return [
        for (final e in _categories.entries)
          {'category_id': e.key, 'category_name': e.value, 'parent_id': 0},
      ];
    case 'get_live_streams':
      return [
        for (final c in _channels)
          if (q['category_id'] == null || q['category_id'] == c.$3)
            {
              'num': c.$1,
              'name': c.$2,
              'stream_type': 'live',
              'stream_id': '${c.$1}', // string on purpose
              // Channel 3 points at a missing logo to exercise fallbacks.
              'stream_icon': '${_base(req)}/logo/${c.$1 == 3 ? 404 : c.$1}.png',
              'epg_channel_id': c.$4,
              'category_id': c.$3,
              'tv_archive': c.$1 == 4 ? 1 : 0,
              'tv_archive_duration': c.$1 == 4 ? '3' : '0',
            },
      ];
    case 'get_vod_categories' || 'get_series_categories':
      return <Object>[];
    case 'get_vod_streams' || 'get_series':
      return <String, Object>{}; // some panels return {} instead of []
    case 'get_short_epg':
      final id = int.tryParse(q['stream_id'] ?? '');
      final ch = _channels.where((c) => c.$1 == id).firstOrNull;
      if (ch == null) return {'epg_listings': <Object>[]};
      return {
        'epg_listings': [
          for (final p
              in _programmes(ch).take(int.tryParse(q['limit'] ?? '') ?? 4))
            {
              'title': base64.encode(utf8.encode(p.$2)),
              'description': base64.encode(utf8.encode(p.$3)),
              'start_timestamp': '${p.$1.millisecondsSinceEpoch ~/ 1000}',
              'stop_timestamp':
                  '${p.$1.add(const Duration(minutes: 30)).millisecondsSinceEpoch ~/ 1000}',
            },
        ],
      };
  }
  return <Object>[];
}

/// Half-hour slots from two hours ago to a day ahead.
Iterable<(DateTime, String, String)> _programmes(
    (int, String, String, String, String) ch) sync* {
  final now = DateTime.now().toUtc();
  var t = DateTime.utc(now.year, now.month, now.day, now.hour)
      .subtract(const Duration(hours: 2));
  final end = now.add(const Duration(hours: 24));
  var n = 1;
  while (t.isBefore(end)) {
    yield (t, '${ch.$2} — Part $n', 'Generated programme $n on ${ch.$2}.');
    t = t.add(const Duration(minutes: 30));
    n++;
  }
}

String _xmltv() {
  String ts(DateTime t) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}${two(t.hour)}${two(t.minute)}00 +0000';
  }

  String esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  final b = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>\n<tv>\n');
  final guide = [
    for (final c in _channels)
      if (c.$4.isNotEmpty) c,
    (0, 'Cinema 1', '2', 'cinema1.test', ''),
  ];
  for (final c in guide) {
    b.writeln(
        '  <channel id="${c.$4}"><display-name>${esc(c.$2)}</display-name></channel>');
  }
  for (final c in guide) {
    for (final p in _programmes(c)) {
      b.writeln('  <programme start="${ts(p.$1)}" '
          'stop="${ts(p.$1.add(const Duration(minutes: 30)))}" channel="${c.$4}">'
          '<title>${esc(p.$2)}</title><desc>${esc(p.$3)}</desc></programme>');
    }
  }
  b.writeln('</tv>');
  return b.toString();
}

String _base(HttpRequest req) =>
    'http://${req.requestedUri.host}:${req.requestedUri.port}';

const _logoColors = [
  [0x6F, 0xA8, 0xFF],
  [0xFF, 0x8A, 0x7A],
  [0x7F, 0xD6, 0xA4],
  [0xF5, 0xB8, 0x41],
  [0xC9, 0xA7, 0xFF],
  [0xFF, 0xB3, 0xD1],
];

/// Minimal PNG encoder: a solid colour with a white band, enough to test
/// logo loading without shipping image files.
List<int> _png(int w, int h, List<int> rgb) {
  final raw = BytesBuilder();
  for (var y = 0; y < h; y++) {
    raw.addByte(0); // filter: none
    final band = y > h * 0.4 && y < h * 0.6;
    for (var x = 0; x < w; x++) {
      raw.add(band && x > w * 0.2 && x < w * 0.8 ? const [255, 255, 255] : rgb);
    }
  }
  List<int> chunk(String type, List<int> data) {
    final body = [...ascii.encode(type), ...data];
    return [..._u32(data.length), ...body, ..._u32(_crc32(body))];
  }

  return [
    0x89,
    0x50,
    0x4E,
    0x47,
    0x0D,
    0x0A,
    0x1A,
    0x0A,
    ...chunk('IHDR', [..._u32(w), ..._u32(h), 8, 2, 0, 0, 0]),
    ...chunk('IDAT', zlib.encode(raw.takeBytes())),
    ...chunk('IEND', const []),
  ];
}

List<int> _u32(int v) => [v >> 24 & 255, v >> 16 & 255, v >> 8 & 255, v & 255];

int _crc32(List<int> bytes) {
  var c = 0xFFFFFFFF;
  for (final b in bytes) {
    c ^= b;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return c ^ 0xFFFFFFFF;
}
