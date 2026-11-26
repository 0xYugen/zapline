import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:zapline_data/zapline_data.dart';

import 'db_write.dart';
import 'layout.dart';

/// User preferences backed by the database's settings table. Defaults are
/// chosen for a TV on first run.
class AppSettings {
  AppSettings(this._db);

  final ZaplineDatabase _db;

  /// Settings as last read or written: every getter used to be a query,
  /// and some run in loops over whole channel lists (channel numbers).
  final _cache = <String, String?>{};

  String? _get(String key) =>
      _cache.containsKey(key) ? _cache[key] : (_cache[key] = _db.setting(key));

  /// Kept at once; stored as soon as the database is free.
  void _put(String key, String? value) {
    _cache[key] = value;
    writeSoon(() => _db.setSetting(key, value));
  }

  /// Forgets what is kept, after settings were written to the database
  /// directly (a restored backup).
  void reload() {
    _cache.clear();
    language.value = _get('language');
  }

  bool _bool(String key, bool fallback) => switch (_get(key)) {
    'true' => true,
    'false' => false,
    _ => fallback,
  };

  int _int(String key, int fallback) =>
      int.tryParse(_get(key) ?? '') ?? fallback;

  /// Number channels 1, 2, 3… instead of using the provider's numbers.
  bool get sequentialNumbers => _bool('sequentialNumbers', false);
  set sequentialNumbers(bool v) => _put('sequentialNumbers', '$v');

  /// Reopen the last watched channel at startup: on by default on TVs,
  /// which are turned on to watch TV.
  bool get resumeLastChannel => _bool('resumeLastChannel', FormFactor.isTv);
  set resumeLastChannel(bool v) => _put('resumeLastChannel', '$v');

  bool get clock24h => _bool('clock24h', true);
  set clock24h(bool v) => _put('clock24h', '$v');

  /// Days of guide to keep ahead. Fewer days, smaller database and faster
  /// syncs: TVs (Fire TV sticks above all) keep 3 by default, which halves
  /// a big guide's import there; other devices a week.
  int get guideDays => _int('guideDays', FormFactor.isTv ? 3 : 7);
  set guideDays(int v) => _put('guideDays', '$v');

  /// Hours between automatic refreshes of each source; 0 turns them off.
  int get refreshHours => _int('refreshHours', 12);
  set refreshHours(int v) => _put('refreshHours', '$v');

  /// Players' volume, 0–100, and whether sound is off.
  int get volume => _int('volume', 100).clamp(0, 100);
  set volume(int v) => _put('volume', '${v.clamp(0, 100)}');
  bool get muted => _bool('muted', false);
  set muted(bool v) => _put('muted', '$v');

  /// Android: play with Zapline's own player (Media3Engine) instead of the
  /// system one through video_player. Off until it is proven on devices.
  bool get ownPlayer => _bool('ownPlayer', false);
  set ownPlayer(bool v) => _put('ownPlayer', '$v');

  /// Phones, with Zapline's player: leaving the app (or turning the
  /// screen off) keeps the sound, with a media notification to pause it.
  bool get backgroundAudio => _bool('backgroundAudio', false);
  set backgroundAudio(bool v) => _put('backgroundAudio', '$v');

  /// With Zapline's player on a TV: the screen switches to the stream's
  /// frame rate (50 Hz for European TV, 24 Hz for films), so motion is
  /// smooth instead of judder. Some TVs blank for a moment as they switch.
  bool get matchFrameRate => _bool('matchFrameRate', false);
  set matchFrameRate(bool v) => _put('matchFrameRate', '$v');

  /// With Zapline's player: while zapping, the channels before and after
  /// the one playing load their first seconds, so Up and Down show the
  /// next at once. Needs a provider allowing more than one connection.
  bool get preloadNeighbours => _bool('preloadNeighbours', false);
  set preloadNeighbours(bool v) => _put('preloadNeighbours', '$v');

  /// The screen stays on while Zapline is open.
  bool get keepScreenOn => _bool('keepScreenOn', true);
  set keepScreenOn(bool v) => _put('keepScreenOn', '$v');

  /// Show "Rai 1 HD", "Rai 1 FHD" and "Rai 1 4K" as one channel.
  bool get mergeVersions => _bool('mergeVersions', true);
  set mergeVersions(bool v) => _put('mergeVersions', '$v');

  /// The same channel from several sources is one entry too: when one
  /// source fails, the next plays it.
  bool get mergeSources => _bool('mergeSources', true);
  set mergeSources(bool v) => _put('mergeSources', '$v');

  /// Which version of a merged channel plays: the best picture, or the
  /// one that uses less data (HD before Full HD and 4K).
  bool get saveData => _bool('saveData', false);
  set saveData(bool v) => _put('saveData', '$v');

  /// Versions picked by hand: channel key ("source/id") by version key.
  Map<String, String> get versionChoices {
    final raw = _get('versionChoices');
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } on FormatException {
      return {};
    }
  }

  set versionChoices(Map<String, String> v) =>
      _put('versionChoices', jsonEncode(v));

  /// Channels the user said have no guide, by channel key: not asked
  /// about again when matching guides.
  Set<String> get noGuideChannels {
    final raw = _get('noGuideChannels');
    if (raw == null) return {};
    try {
      return {for (final k in jsonDecode(raw) as List) '$k'};
    } on FormatException {
      return {};
    }
  }

  set noGuideChannels(Set<String> v) =>
      _put('noGuideChannels', jsonEncode(v.toList()));

  Map<String, String> _map(String key) {
    final raw = _get(key);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) => MapEntry('$k', '$v'));
    } on FormatException {
      return {};
    }
  }

  /// "Send to TV", phone side: token by paired device id.
  Map<String, String> get castPairs => _map('castPairs');
  set castPairs(Map<String, String> v) => _put('castPairs', jsonEncode(v));

  /// "Send to TV", receiving side: paired phone name by token.
  Map<String, String> get castTokens => _map('castTokens');
  set castTokens(Map<String, String> v) => _put('castTokens', jsonEncode(v));

  /// This installation's id for "Send to TV", made once.
  String castDeviceId(String Function() make) {
    final id = _get('castDeviceId');
    if (id != null) return id;
    final fresh = make();
    _put('castDeviceId', fresh);
    return fresh;
  }

  /// How the picture fills the screen.
  BoxFit get videoFit => switch (_get('videoFit')) {
    'cover' => BoxFit.cover,
    'fill' => BoxFit.fill,
    _ => BoxFit.contain,
  };
  set videoFit(BoxFit v) => _put('videoFit', v.name);

  /// The app's language: `null` follows the device, else a language code
  /// ("it", "en"). Listen to [language] to rebuild on change.
  late final language = ValueNotifier<String?>(_get('language'));

  void setLanguage(String? code) {
    _put('language', code);
    language.value = code;
  }

  /// Ask GitHub, at most once a day, whether a newer Zapline is out.
  bool get checkUpdates => _bool('checkUpdates', true);
  set checkUpdates(bool v) => _put('checkUpdates', '$v');

  /// When updates were last looked for (ms since epoch).
  int get updateCheckedAt => _int('updateCheckedAt', 0);
  set updateCheckedAt(int v) => _put('updateCheckedAt', '$v');

  /// The newer release last found, as JSON, kept until it's installed.
  String? get pendingUpdate => _get('pendingUpdate');
  set pendingUpdate(String? v) => _put('pendingUpdate', v);

  /// The build already announced with a message, so it's said once.
  int get updateAnnounced => _int('updateAnnounced', 0);
  set updateAnnounced(int v) => _put('updateAnnounced', '$v');

  /// Hash of the parental PIN; `null` when none is set.
  String? get pinHash => _get('pinHash');
  set pinHash(String? v) => _put('pinHash', v);
}
