import 'package:zapline_core/zapline_core.dart';

import 'app_state.dart';
import 'l10n.dart';

/// Pseudo-groups shown before the provider's groups. `null` is "All
/// channels". The NUL prefix keeps them from clashing with real titles.
const favouritesGroup = '\u0000favourites';
const recentGroup = '\u0000recent';

/// Every group to offer, pseudo-groups first.
List<String?> groupsOf(AppState state) => [
  null,
  if (state.hasRecents) recentGroup,
  if (state.hasFavourites) favouritesGroup,
  ...state.groups,
];

String groupLabel(AppLocalizations l, String? group) => switch (group) {
  null => l.allChannels,
  favouritesGroup => l.favourites,
  recentGroup => l.recent,
  '' => l.noGroup,
  final g => g,
};

List<Channel> channelsIn(AppState state, String? group) => switch (group) {
  favouritesGroup => state.favourites(),
  recentGroup => state.recents(),
  final g => state.channels(group: g),
};

/// Caches [channelsIn] until the group or the stored channels change.
/// Large lists load off screen: meanwhile the list shown before stays.
class ChannelListCache {
  (String?, int, int)? _key;
  List<Channel>? _list;

  /// `null` only while the first list loads.
  List<Channel>? get(AppState state, String? group) {
    // Favourites and recents change without the channels changing.
    final key = (
      group,
      state.version,
      switch (group) {
        favouritesGroup => state.favouritesVersion,
        recentGroup => state.recentsVersion,
        _ => 0,
      },
    );
    if (key == _key) return _list;
    final list = switch (group) {
      favouritesGroup => state.favourites(),
      recentGroup => state.recents(),
      final g => state.channelsReady(g),
    };
    if (list == null) return _list;
    _key = key;
    return _list = list;
  }
}
