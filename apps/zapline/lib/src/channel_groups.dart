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
class ChannelListCache {
  (String?, int)? _key;
  List<Channel> _list = const [];

  List<Channel> get(AppState state, String? group) {
    final key = (group, state.version);
    if (key != _key) {
      _key = key;
      _list = channelsIn(state, group);
    }
    return _list;
  }
}
