import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:zapline_data/zapline_data.dart';

/// User preferences backed by the database's settings table. Defaults are
/// chosen for a TV on first run.
class AppSettings {
  AppSettings(this._db);

  final ZaplineDatabase _db;

  bool _bool(String key, bool fallback) => switch (_db.setting(key)) {
    'true' => true,
    'false' => false,
    _ => fallback,
  };

  int _int(String key, int fallback) =>
      int.tryParse(_db.setting(key) ?? '') ?? fallback;

  /// Number channels 1, 2, 3… instead of using the provider's numbers.
  bool get sequentialNumbers => _bool('sequentialNumbers', false);
  set sequentialNumbers(bool v) => _db.setSetting('sequentialNumbers', '$v');

  /// Reopen the last watched channel at startup.
  bool get resumeLastChannel => _bool('resumeLastChannel', false);
  set resumeLastChannel(bool v) => _db.setSetting('resumeLastChannel', '$v');

  bool get clock24h => _bool('clock24h', true);
  set clock24h(bool v) => _db.setSetting('clock24h', '$v');

  /// Days of guide to keep ahead. Fewer days, smaller database and faster
  /// syncs on low-end sticks.
  int get guideDays => _int('guideDays', 7);
  set guideDays(int v) => _db.setSetting('guideDays', '$v');

  /// Hours between automatic refreshes of each source; 0 turns them off.
  int get refreshHours => _int('refreshHours', 12);
  set refreshHours(int v) => _db.setSetting('refreshHours', '$v');

  /// Show "Rai 1 HD", "Rai 1 FHD" and "Rai 1 4K" as one channel.
  bool get mergeVersions => _bool('mergeVersions', true);
  set mergeVersions(bool v) => _db.setSetting('mergeVersions', '$v');

  /// Which version of a merged channel plays: the best picture, or the
  /// one that uses less data (HD before Full HD and 4K).
  bool get saveData => _bool('saveData', false);
  set saveData(bool v) => _db.setSetting('saveData', '$v');

  /// Versions picked by hand: channel key ("source/id") by version key.
  Map<String, String> get versionChoices {
    final raw = _db.setting('versionChoices');
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } on FormatException {
      return {};
    }
  }

  set versionChoices(Map<String, String> v) =>
      _db.setSetting('versionChoices', jsonEncode(v));

  /// How the picture fills the screen.
  BoxFit get videoFit => switch (_db.setting('videoFit')) {
    'cover' => BoxFit.cover,
    'fill' => BoxFit.fill,
    _ => BoxFit.contain,
  };
  set videoFit(BoxFit v) => _db.setSetting('videoFit', v.name);

  /// The app's language: `null` follows the device, else a language code
  /// ("it", "en"). Listen to [language] to rebuild on change.
  late final language = ValueNotifier<String?>(_db.setting('language'));

  void setLanguage(String? code) {
    _db.setSetting('language', code);
    language.value = code;
  }

  /// Hash of the parental PIN; `null` when none is set.
  String? get pinHash => _db.setting('pinHash');
  set pinHash(String? v) => _db.setSetting('pinHash', v);
}
