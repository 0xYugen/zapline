import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lineup_core/lineup_core.dart';

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

  static const _maxBytes = 512 * 1024;

  /// Enables the disk layer; without it logos are only cached in memory.
  static Future<void> init(Directory cacheRoot) async {
    final dir = Directory('${cacheRoot.path}${Platform.pathSeparator}logos');
    await dir.create(recursive: true);
    _dir = dir;
  }

  /// Test hook replacing network and disk.
  @visibleForTesting
  static Future<Uint8List> Function(String url)? debugLoader;

  static Future<Uint8List> load(String url) {
    if (_failed.contains(url)) {
      return Future.error(StateError('logo previously failed'));
    }
    // Block body on purpose: `() => _inflight.remove(url)` would return the
    // future itself, and whenComplete would then wait on itself forever.
    return _inflight[url] ??= _fetch(url).whenComplete(() {
      _inflight.remove(url);
    });
  }

  static Future<Uint8List> _fetch(String url) async {
    try {
      final override = debugLoader;
      return override != null ? await override(url) : await _load(url);
    } catch (_) {
      _failed.add(url);
      rethrow;
    }
  }

  static Future<Uint8List> _load(String url) async {
    final dir = _dir;
    final file = dir == null
        ? null
        : File(
            '${dir.path}${Platform.pathSeparator}'
            '${sha1.convert(utf8.encode(url))}',
          );
    if (file != null && await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) return bytes;
    }
    final res = await _client
        .get(
          Uri.parse(url),
          headers: {'User-Agent': XtreamClient.defaultUserAgent},
        )
        .timeout(const Duration(seconds: 10));
    final type = res.headers['content-type'] ?? '';
    if (res.statusCode != 200 ||
        res.bodyBytes.isEmpty ||
        res.bodyBytes.length > _maxBytes ||
        (type.isNotEmpty && !type.startsWith('image/'))) {
      throw StateError('HTTP ${res.statusCode} $type');
    }
    await file?.writeAsBytes(res.bodyBytes, flush: false);
    return res.bodyBytes;
  }

  @visibleForTesting
  static void debugReset() {
    _failed.clear();
    _inflight.clear();
  }
}

/// Image provider backed by [LogoCache].
@immutable
class CachedLogo extends ImageProvider<CachedLogo> {
  const CachedLogo(this.url);

  final String url;

  @override
  Future<CachedLogo> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(CachedLogo key, ImageDecoderCallback decode) =>
      MultiFrameImageStreamCompleter(
        codec: LogoCache.load(url)
            .then((b) => ui.ImmutableBuffer.fromUint8List(b))
            .then(decode),
        scale: 1,
        debugLabel: url,
      );

  @override
  bool operator ==(Object other) => other is CachedLogo && other.url == url;

  @override
  int get hashCode => url.hashCode;
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
          CachedLogo(url.toString()),
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

  String get _initials {
    final words = name
        .replaceAll(RegExp(r'^[A-Za-z]{2,3}\s*[:|]\s*'), '')
        .split(RegExp(r'[\s\-_.]+'))
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
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: width,
      height: height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: LineupColors.ground,
          fontWeight: FontWeight.w800,
          fontSize: height * 0.36,
        ),
      ),
    );
  }
}
