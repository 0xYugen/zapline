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

  /// How the picture fills the screen.
  BoxFit get videoFit => switch (_db.setting('videoFit')) {
    'cover' => BoxFit.cover,
    'fill' => BoxFit.fill,
    _ => BoxFit.contain,
  };
  set videoFit(BoxFit v) => _db.setSetting('videoFit', v.name);

  /// Hash of the parental PIN; `null` when none is set.
  String? get pinHash => _db.setting('pinHash');
  set pinHash(String? v) => _db.setSetting('pinHash', v);
}
