import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'layout.dart';

/// Where releases are published.
const releasesRepo = '0xYugen/zapline';

/// Set by release builds: `--dart-define=ZAPLINE_VERSION=0.1.0 (42)`.
const appVersion = String.fromEnvironment(
  'ZAPLINE_VERSION',
  defaultValue: 'development build',
);

/// Store builds (`--dart-define=ZAPLINE_STORE_BUILD=true`) are updated by
/// the store, which doesn't allow apps to install their own updates.
const updatesSupported = !bool.fromEnvironment('ZAPLINE_STORE_BUILD');

/// The build number in a version label: `0.1.0 (54)` → 54. Development
/// builds have none and never look for updates.
int? buildOf(String version) =>
    int.tryParse(RegExp(r'\((\d+)\)').firstMatch(version)?.group(1) ?? '');

/// A newer release than the running build.
class AppUpdate {
  const AppUpdate({
    required this.build,
    required this.version,
    required this.page,
    this.apk,
    this.apkSize,
  });

  final int build;

  /// As shown: `0.1.0 (60)`.
  final String version;

  /// The release page, for desktops and as a fallback.
  final Uri page;

  /// The Android package for this device, when the release has one.
  final Uri? apk;
  final int? apkSize;

  Map<String, Object?> toJson() => {
    'build': build,
    'version': version,
    'page': '$page',
    if (apk != null) 'apk': '$apk',
    if (apkSize != null) 'size': apkSize,
  };

  static AppUpdate? fromJson(Object? json) {
    if (json is! Map) return null;
    final build = json['build'], version = json['version'];
    final page = Uri.tryParse('${json['page']}');
    if (build is! int || version is! String || page == null) return null;
    return AppUpdate(
      build: build,
      version: version,
      page: page,
      apk: json['apk'] is String ? Uri.tryParse(json['apk'] as String) : null,
      apkSize: json['size'] as int?,
    );
  }

  /// Reads GitHub's "latest release" answer. Tags are `v<version>-<build>`.
  static AppUpdate? fromRelease(Map<String, Object?> json, {required bool tv}) {
    final tag = json['tag_name'];
    final page = Uri.tryParse('${json['html_url']}');
    if (tag is! String || page == null) return null;
    final m = RegExp(r'^v?(.+)-(\d+)$').firstMatch(tag);
    if (m == null) return null;
    final build = int.parse(m.group(2)!);
    final assets = {
      for (final a in (json['assets'] as List?) ?? const [])
        if (a is Map) '${a['name']}': a,
    };
    // TVs, and phones that aren't 64-bit ARM, take the package with both
    // ARM builds.
    final phone = !tv && Abi.current() == Abi.androidArm64;
    final asset =
        (phone ? assets['zapline-phone.apk'] : null) ??
        assets['zapline-tv.apk'];
    return AppUpdate(
      build: build,
      version: '${m.group(1)} ($build)',
      page: page,
      apk: Uri.tryParse('${asset?['browser_download_url'] ?? ''}'),
      apkSize: asset?['size'] as int?,
    );
  }
}

/// Asks GitHub for the latest release and installs it on Android.
class Updater {
  Updater({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  final http.Client _http;

  /// The latest release when it is newer than [currentBuild], else null.
  /// One anonymous request to GitHub's public API.
  Future<AppUpdate?> check(int currentBuild) async {
    final res = await _http
        .get(
          Uri.https('api.github.com', '/repos/$releasesRepo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final json = jsonDecode(res.body);
    if (json is! Map<String, Object?>) return null;
    final update = AppUpdate.fromRelease(json, tv: FormFactor.isTv);
    return update != null && update.build > currentBuild ? update : null;
  }

  /// Downloads the update's package into the app's cache, reporting the
  /// share done (0 to 1).
  Future<File> download(
    AppUpdate update, {
    void Function(double done)? onProgress,
  }) async {
    final url = update.apk;
    if (url == null) throw StateError('No package for this device');
    final res = await _http
        .send(http.Request('GET', url))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}');
    final total = update.apkSize ?? res.contentLength ?? 0;
    final file = File(
      '${(await getTemporaryDirectory()).path}/zapline-update.apk',
    );
    final sink = file.openWrite();
    var got = 0;
    try {
      await for (final chunk in res.stream.timeout(
        const Duration(seconds: 45),
      )) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress?.call(got / total);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && got != total) {
      throw const HttpException('Download incomplete');
    }
    return file;
  }

  /// Hands the package to Android's installer, which asks to confirm and
  /// only accepts it if it is signed with Zapline's own key. Returns false
  /// when Android first wants Zapline allowed to install apps (its settings
  /// page is opened for that).
  Future<bool> install(File apk) async {
    final r = await const MethodChannel('zapline/device')
        .invokeMethod<String>('installApk', {'path': apk.path});
    return r != 'permission';
  }

  /// Whether this platform installs from inside the app.
  static bool get installsInApp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
