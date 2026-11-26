import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:zapline_core/zapline_core.dart';

import '../theme.dart';

/// Disk cache for channel logos. Logos rarely change and lists show
/// hundreds of them, so each is fetched once and kept on disk; decoding
/// happens at display size (see [ChannelLogo]) to keep memory low on TV
/// sticks.
class LogoCache {
  LogoCache._();

  static Directory? _dir;
  static final _client = http.Client();
  static final _failed = <String>{};
  static final _inflight = <String, Future<Uint8List>>{};

  // Logos are small; film posters and backdrops can reach a few MB.
  static const _maxBytes = 3 * 1024 * 1024;

  /// Enables the disk layer; without it logos are only cached in memory.
  static Future<void> init(Directory cacheRoot) async {
    final dir = Directory('${cacheRoot.path}${Platform.pathSeparator}logos');
    await dir.create(recursive: true);
    _dir = dir;
    // Posters of a big catalogue would fill a TV stick: keep the most
    // recently fetched, within a budget. Listing thousands of files is
    // slow on a stick: once a day at most, well after the first screen.
    Timer(const Duration(seconds: 30), () => unawaited(trimDaily(dir)));
  }

  /// [trim], if it hasn't run in the last day.
  @visibleForTesting
  static Future<void> trimDaily(
    Directory dir, {
    DateTime? now,
    int budget = _diskBudget,
  }) async {
    final mark = File('${dir.path}${Platform.pathSeparator}.trimmed');
    final at = now ?? DateTime.now();
    try {
      if (await mark.exists() &&
          at.difference(await mark.lastModified()) < const Duration(days: 1)) {
        return;
      }
      await trim(dir, budget: budget);
      await mark.writeAsString('');
      await mark.setLastModified(at);
    } on FileSystemException {
      // Next start tries again.
    }
  }

  /// Downloads at once: more only queue on a TV stick's Wi-Fi and slow the
  /// stream playing. The newest request goes first: the rows on screen.
  static const parallel = 6;
  static int _running = 0;
  static final _waiting = <Completer<void>>[];

  static Future<T> _gated<T>(Future<T> Function() fetch) async {
    if (_running >= parallel) {
      final turn = Completer<void>();
      _waiting.add(turn);
      await turn.future;
    } else {
      _running++;
    }
    try {
      return await fetch();
    } finally {
      if (_waiting.isNotEmpty) {
        // The slot passes straight to the newest waiting.
        _waiting.removeLast().complete();
      } else {
        _running--;
      }
    }
  }

  /// Logos are drawn at most about this size: one larger is kept on disk
  /// scaled down, so reading and decoding it later costs a fraction.
  static const thumbSize = 160;

  static const _diskBudget = 150 * 1024 * 1024;

  /// Deletes the oldest cached images until the folder is back under
  /// 80% of the budget.
  @visibleForTesting
  static Future<void> trim(Directory dir, {int budget = _diskBudget}) async {
    try {
      final files = <(File, int, DateTime)>[];
      var total = 0;
      await for (final e in dir.list()) {
        if (e is! File || e.uri.pathSegments.last.startsWith('.')) continue;
        final st = await e.stat();
        files.add((e, st.size, st.modified));
        total += st.size;
      }
      if (total <= budget) return;
      files.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (f, size, _) in files) {
        if (total <= budget * 0.8) break;
        await f.delete();
        total -= size;
      }
    } on FileSystemException {
      // A busy or vanished file: next start tries again.
    }
  }

  /// Test hook replacing network and disk.
  @visibleForTesting
  static Future<Uint8List> Function(String url)? debugLoader;

  /// The image at [url]; with [thumb], scaled down to [thumbSize] if
  /// larger (channel logos, not posters).
  static Future<Uint8List> load(String url, {bool thumb = false}) {
    if (_failed.contains(url)) {
      return Future.error(StateError('logo previously failed'));
    }
    final key = thumb ? '$url#thumb' : url;
    // Block body on purpose: `() => _inflight.remove(url)` would return the
    // future itself, and whenComplete would then wait on itself forever.
    return _inflight[key] ??= _fetch(url, thumb).whenComplete(() {
      _inflight.remove(key);
    });
  }

  static Future<Uint8List> _fetch(String url, bool thumb) async {
    try {
      final override = debugLoader;
      return override != null
          ? await _gated(() => override(url))
          : await _load(url, thumb);
    } catch (_) {
      _failed.add(url);
      rethrow;
    }
  }

  static Future<Uint8List> _load(String url, bool thumb) async {
    final dir = _dir;
    final name = sha1.convert(utf8.encode(url)).toString();
    File? at(String n) =>
        dir == null ? null : File('${dir.path}${Platform.pathSeparator}$n');
    final file = at(thumb ? '$name-t' : name);
    if (file != null && await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
    // A full-size copy fetched before (a poster) serves for a thumbnail.
    final full = thumb ? at(name) : null;
    Uint8List? bytes;
    if (full != null && await full.exists()) bytes = await full.readAsBytes();
    if (bytes == null || bytes.isEmpty) {
      final res = await _gated(
        () => _client
            .get(
              Uri.parse(url),
              headers: {'User-Agent': XtreamClient.defaultUserAgent},
            )
            .timeout(const Duration(seconds: 10)),
      );
      final type = res.headers['content-type'] ?? '';
      if (res.statusCode != 200 ||
          res.bodyBytes.isEmpty ||
          res.bodyBytes.length > _maxBytes ||
          (type.isNotEmpty && !type.startsWith('image/'))) {
        throw StateError('HTTP ${res.statusCode} $type');
      }
      bytes = res.bodyBytes;
      if (!thumb) {
        await file?.writeAsBytes(bytes, flush: false);
        return bytes;
      }
    }
    final small = await shrink(bytes);
    await file?.writeAsBytes(small, flush: false);
    return small;
  }

  /// [bytes] as a PNG at most [thumbSize] wide and high, or unchanged when
  /// already small (or not an image Flutter can read: it fails later, as
  /// before).
  @visibleForTesting
  static Future<Uint8List> shrink(Uint8List bytes) async {
    // Small files are small pictures: not worth the work.
    if (bytes.length < 24 * 1024) return bytes;
    try {
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (w, h) {
          if (w <= thumbSize && h <= thumbSize) return ui.TargetImageSize();
          return w >= h
              ? ui.TargetImageSize(width: thumbSize)
              : ui.TargetImageSize(height: thumbSize);
        },
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      if (png == null || png.lengthInBytes >= bytes.length) return bytes;
      return png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    } catch (_) {
      return bytes;
    }
  }

  @visibleForTesting
  static void debugReset() {
    _failed.clear();
    _inflight.clear();
    _waiting.clear();
    _running = 0;
  }
}

/// Image provider backed by [LogoCache].
@immutable
class CachedLogo extends ImageProvider<CachedLogo> {
  const CachedLogo(this.url, {this.thumb = false});

  final String url;

  /// Kept scaled down (channel logos, see [LogoCache.thumbSize]).
  final bool thumb;

  @override
  Future<CachedLogo> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedLogo key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: LogoCache.load(
          url,
          thumb: thumb,
        ).then((b) => ui.ImmutableBuffer.fromUint8List(b)).then(decode),
        scale: 1,
        debugLabel: url,
      );

  @override
  bool operator ==(Object other) =>
      other is CachedLogo && other.url == url && other.thumb == thumb;

  @override
  int get hashCode => Object.hash(url, thumb);
}

/// A channel's logo, or a badge with its initials when there is none or it
/// fails to load.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({
    super.key,
    required this.channel,
    this.width = 56,
    this.height = 40,
  });

  final Channel channel;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = channel.logoUrl;
    final badge = _Initials(name: channel.name, width: width, height: height);
    if (url == null || !url.hasScheme) return badge;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return SizedBox(
      width: width,
      height: height,
      child: Image(
        image: ResizeImage(
          CachedLogo(url.toString(), thumb: width * dpr <= LogoCache.thumbSize),
          width: (width * dpr).round(),
          height: (height * dpr).round(),
          policy: ResizeImagePolicy.fit,
        ),
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => badge,
        frameBuilder: (_, child, frame, sync) =>
            sync || frame != null ? child : badge,
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({
    required this.name,
    required this.width,
    required this.height,
  });

  final String name;
  final double width;
  final double height;

  static const _palette = [
    Color(0xFF6FA8FF),
    Color(0xFFFF8A7A),
    Color(0xFF7FD6A4),
    Color(0xFFF5B841),
    Color(0xFFC9A7FF),
    Color(0xFFFFB3D1),
  ];

  static final _countryTag = RegExp(r'^[A-Za-z]{2,3}\s*[:|]\s*');
  static final _separators = RegExp(r'[\s\-_.]+');

  String get _initials {
    final words = name
        .replaceAll(_countryTag, '')
        .split(_separators)
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first
          .substring(0, words.first.length.clamp(1, 2))
          .toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // A quiet tile, its letters tinted: a list of them reads as channels
    // without a logo, not as a row of coloured blocks.
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.10),
          ZaplineColors.surfaceHigh,
        ),
        borderRadius: BorderRadius.circular(height * 0.2),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: Color.lerp(color, ZaplineColors.text, 0.35),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          fontSize: height * 0.34,
        ),
      ),
    );
  }
}
