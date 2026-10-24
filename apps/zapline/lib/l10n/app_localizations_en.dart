// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get allChannels => 'All channels';

  @override
  String get favourites => 'Favourites';

  @override
  String get recent => 'Recent';

  @override
  String get noGroup => 'No group';

  @override
  String get groups => 'Groups';

  @override
  String get allGroups => 'All groups';

  @override
  String get findGroup => 'Find a group';

  @override
  String get noChannelsInGroup => 'No channels in this group.';

  @override
  String get groupLocked => 'This group is locked';

  @override
  String get unlockWithPin => 'Unlock with PIN';

  @override
  String get pressOkForPin => 'Press OK to enter the PIN.';

  @override
  String get enterPin => 'Enter the PIN';

  @override
  String get wrongPin => 'Wrong PIN';

  @override
  String get pinDelete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get tvGuide => 'TV guide';

  @override
  String get search => 'Search';

  @override
  String get sources => 'Sources';

  @override
  String get settings => 'Settings';

  @override
  String get channels => 'Channels';

  @override
  String get guide => 'Guide';

  @override
  String get liveTv => 'Live TV';

  @override
  String get holdOkHint =>
      'Hold OK on a channel for favourites, hiding and its guide';

  @override
  String get noGuideInfo => 'No guide information';

  @override
  String get noGuide => 'No guide';

  @override
  String get noGuideAtTime => 'No guide for this time';

  @override
  String get earlier => 'Earlier';

  @override
  String get later => 'Later';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get now => 'Now';

  @override
  String tonightAt(String time) {
    return 'Tonight $time';
  }

  @override
  String get pickTime => 'Pick a time';

  @override
  String atTime(String time) {
    return 'At $time';
  }

  @override
  String thenAt(String time, String title) {
    return 'then $time $title';
  }

  @override
  String get onNow => 'ON NOW';

  @override
  String get replay => 'REPLAY';

  @override
  String get watchLive => 'Watch live';

  @override
  String get noGuideForChannel =>
      'No guide for this channel.\nYou can link one from Settings → Sources → Fix TV guide.';

  @override
  String get inTheTvGuide => 'In the TV guide';

  @override
  String get channelOrProgramme => 'Channel or programme';

  @override
  String get nothingFound => 'Nothing found.';

  @override
  String get fixTvGuide => 'Fix TV guide';

  @override
  String get fixDone => 'Done. Press Back to return.';

  @override
  String get fixAllMatched => 'Every channel of this source has a guide.';

  @override
  String fixUnmatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels have no guide.',
      one: '1 channel has no guide.',
    );
    return '$_temp0 Pick one, then choose the matching guide channel.';
  }

  @override
  String get pickChannelAbove => 'Pick a channel above.';

  @override
  String suggestionsFor(String name) {
    return 'Suggestions for $name';
  }

  @override
  String get guideChannels => 'Guide channels';

  @override
  String get searchTheGuide => 'Search the guide';

  @override
  String get nothingFoundTryAnother => 'Nothing found. Try another name.';

  @override
  String get backupTitle => 'Backup and restore';

  @override
  String get backupIntro =>
      'Save your sources, favourites and guide fixes to a file, or bring them back on a new device. Open the page shown here in a browser on the same network.';

  @override
  String get backupPrivate =>
      'The backup file contains your source passwords: keep it private.';

  @override
  String get backupOpenOnComputer => 'On a computer on the same Wi-Fi, open';

  @override
  String get backupOpenHere => 'On this computer, open';

  @override
  String backupCode(String pin) {
    return 'Code $pin';
  }

  @override
  String get noLocalNetwork =>
      'This device is not connected to a local network.';

  @override
  String restoring(String progress) {
    return 'Restoring… $progress';
  }

  @override
  String get pressBackWhenDone => 'Press Back when you are done.';

  @override
  String get useYourPhone => 'Use your phone';

  @override
  String get backupScan => 'Scan to download a backup or restore one.';

  @override
  String get qrLabel => 'QR code to add a source from your phone';

  @override
  String get orOpenOnPhone => 'Or open on your phone';

  @override
  String get code => 'Code';

  @override
  String get addToFavourites => 'Add to favourites';

  @override
  String get removeFromFavourites => 'Remove from favourites';

  @override
  String get hideChannel => 'Hide this channel';

  @override
  String get hiddenHint => 'Show it again from the source\'s hidden channels';

  @override
  String get fixItsGuide => 'Fix its TV guide';

  @override
  String get freeEpgByCountry => 'Free EPG by country';

  @override
  String get freeEpgNote =>
      'Programme listings from public sources (iptv-epg.org, epgshare01, open-epg.com), free for legal use. Channels are matched by name.';

  @override
  String get findCountry => 'Find a country';

  @override
  String minutesLeft(int minutes) {
    return '$minutes min left';
  }

  @override
  String hoursMinutesLeft(int hours, int minutes) {
    return '$hours h $minutes min left';
  }

  @override
  String get language => 'Language';

  @override
  String get languageDevice => 'Same as device';

  @override
  String get watch => 'Watch';

  @override
  String get fromTheStart => 'From the start';

  @override
  String get replayAction => 'Replay';

  @override
  String get remindMe => 'Remind me';

  @override
  String get reminderSet => 'Reminder set';

  @override
  String get watchChannel => 'Watch channel';

  @override
  String nextAt(String time, String title) {
    return 'Next: $time $title';
  }

  @override
  String get continueWatching => 'Continue watching';

  @override
  String get favouritesEmpty =>
      'No favourites yet.\nHold a channel and choose “Add to favourites”.';

  @override
  String reminderNow(String title, String channel) {
    return '$title is starting on $channel';
  }

  @override
  String get searchTooltip => 'Search channels and programmes';

  @override
  String get lessThanAMinute => 'Ending now';

  @override
  String get back => 'Back';

  @override
  String get previousChannel => 'Previous channel';

  @override
  String get nextChannel => 'Next channel';

  @override
  String get backToLive => 'Back to live';

  @override
  String get watchFromStart => 'Watch from the start';

  @override
  String get startShort => 'START';

  @override
  String get liveShort => 'LIVE';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get catchUpBadge => 'CATCH-UP';

  @override
  String get pictureSize => 'Picture: fit, zoom, stretch';

  @override
  String get channelList => 'Channels';

  @override
  String get programmeInfo => 'Programme info';

  @override
  String get audioAndSubtitles => 'Audio and subtitles';

  @override
  String get audio => 'Audio';

  @override
  String get subtitles => 'Subtitles';

  @override
  String get subtitlesOff => 'Off';

  @override
  String trackNumber(int n) {
    return 'Track $n';
  }

  @override
  String get noOtherTracks => 'This channel has a single audio track.';

  @override
  String get swipeHint => 'Swipe up or down to change channel';

  @override
  String get noArchive => 'No archive for this programme';

  @override
  String get channelUnavailable => 'This channel is not available right now';

  @override
  String get archiveUnavailable =>
      'This programme is not available in the archive';

  @override
  String get tryAnotherChannelKeys =>
      'Press Up or Down to try another channel.';

  @override
  String get tryAnotherChannelTouch =>
      'Swipe up or down to try another channel.';

  @override
  String get pressRightForLive => 'Press Right to go back to live.';

  @override
  String catchUpLine(String title) {
    return 'Catch-up: $title';
  }

  @override
  String nowLine(String title) {
    return 'Now: $title';
  }

  @override
  String get prevChannelKey => 'Previous channel (Page Up)';

  @override
  String get nextChannelKey => 'Next channel (Page Down)';

  @override
  String get channelListKey => 'Channel list (Enter)';

  @override
  String get tuning => 'tuning…';

  @override
  String zapTime(int ms) {
    return 'zap $ms ms';
  }

  @override
  String get refreshing => 'Refreshing…';

  @override
  String get refreshed => 'Refreshed.';

  @override
  String refreshFailed(String error) {
    return 'Refresh failed: $error';
  }

  @override
  String get enterFullLink => 'Enter a full link, starting with http.';

  @override
  String get guideAdded => 'Guide added. Refresh to load it.';

  @override
  String loadingFreeEpg(String country) {
    return 'Loading the free EPG for $country…';
  }

  @override
  String freeEpgAdded(String country, int matched, int total) {
    return '$country EPG added: TV guide for $matched of $total channels.';
  }

  @override
  String get shiftSaved => 'Guide shift saved. Refresh to apply it.';

  @override
  String get noGroupChannels => 'Channels without a group';

  @override
  String get setPinFirst => 'Set a PIN in Settings before locking groups.';

  @override
  String get unlockGroup => 'Unlock (no PIN needed)';

  @override
  String get lockWithPin => 'Lock with PIN';

  @override
  String get followFilterAgain => 'Follow the filter again';

  @override
  String get sectionGuide => 'TV guide (EPG)';

  @override
  String get sectionGroups => 'Groups and filters';

  @override
  String get sectionHidden => 'Hidden channels';

  @override
  String get sectionName => 'Name and login';

  @override
  String get name => 'Name';

  @override
  String get nameSaved => 'Name saved.';

  @override
  String get save => 'Save';

  @override
  String get server => 'Server';

  @override
  String get username => 'Username';

  @override
  String get tvGuidesEpg => 'TV guides (EPG)';

  @override
  String get epgIntro =>
      'The EPG from the source itself is loaded automatically. Add more EPG links (XMLTV) here; the first match per channel wins.';

  @override
  String get addFreeEpgByCountry => 'Add a free EPG by country';

  @override
  String freeEpgEntry(String country, String host) {
    return 'Free EPG · $country ($host)';
  }

  @override
  String get guideRemoved => 'Guide removed.';

  @override
  String get remove => 'Remove';

  @override
  String get addEpgLink => 'Add an EPG link (XMLTV, .xml or .xml.gz)';

  @override
  String get add => 'Add';

  @override
  String get guideTimeShift => 'Guide time shift';

  @override
  String get guideTimeShiftHint => 'For guides that show the wrong times.';

  @override
  String get refreshNow => 'Refresh now';

  @override
  String get showTheseGroups => 'Show these groups';

  @override
  String get filterHelp =>
      'Words separated by commas. IT matches \"IT | Sport\" but not \"Hits\"; ital* matches Italia and Italy; IT| matches that exact text. Hiding always wins.';

  @override
  String get presetItalian => 'Italian only';

  @override
  String get presetAdult => 'Hide adult';

  @override
  String get presetVod => 'Hide VOD and series';

  @override
  String get clear => 'Clear';

  @override
  String get showOnlyGroupsWith => 'Show only groups with (empty = all)';

  @override
  String get hideGroupsWith => 'Hide groups with';

  @override
  String filterPreview(int groups, int all, int channels) {
    return 'Shows $groups of $all groups · $channels channels';
  }

  @override
  String get filterApplied => 'Filter applied.';

  @override
  String get applyFilter => 'Apply filter';

  @override
  String get applied => 'Applied';

  @override
  String get groupsHelp =>
      'Tap shows or hides a group. Hold to lock it with the PIN or to make it follow the filter again.';

  @override
  String groupState(int count, String state, String by) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'hidden': 'hidden',
      'other': 'shown',
    });
    String _temp1 = intl.Intl.selectLogic(by, {
      'filter': ' by filter',
      'other': '',
    });
    return '$count · $_temp0$_temp1';
  }

  @override
  String get noHiddenChannels =>
      'No hidden channels. Hold a channel and choose “Hide this channel” to hide it.';

  @override
  String get showAgain => 'Show again';

  @override
  String refreshResult(int channels, int programmes) {
    return '$channels channels, $programmes guide entries';
  }

  @override
  String refreshGuideFailed(String errors) {
    return 'Channels updated, guide failed ($errors)';
  }

  @override
  String removeSourceTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get removeSourceMessage =>
      'Its channels, favourites and guide links go too. You can add it again later.';

  @override
  String get removeSource => 'Remove this source';

  @override
  String channelsWithoutGuide(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels still have no TV guide.',
      one: '1 channel still has no TV guide.',
    );
    return '$_temp0';
  }

  @override
  String addFreeEpgFor(String country) {
    return 'Add the free EPG for $country';
  }

  @override
  String get addFreeEpg => 'Add a free EPG';

  @override
  String get matchThem => 'Match them';

  @override
  String get guideFromSource => 'From the source';

  @override
  String freeEpgShort(String countries) {
    return 'free EPG $countries';
  }

  @override
  String extraGuides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more guides',
      one: '1 more guide',
    );
    return '$_temp0';
  }

  @override
  String shiftedBy(String value) {
    return 'shifted $value';
  }

  @override
  String get filterOn => 'Filter on';

  @override
  String groupsShown(int shown, int all) {
    return '$shown of $all groups shown';
  }

  @override
  String hiddenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hidden',
      one: '1 hidden',
      zero: 'None',
    );
    return '$_temp0';
  }

  @override
  String syncingProgress(String progress) {
    return 'Updating… $progress';
  }

  @override
  String epgFailed(String errors) {
    return 'EPG could not be loaded: $errors';
  }

  @override
  String get epgEmptyPerChannel =>
      'The source sent an empty EPG; what\'s on now is asked channel by channel.';

  @override
  String get epgEmpty =>
      'The source sent an empty EPG. Add a free EPG or a link.';

  @override
  String updatedAt(String day, String time) {
    return 'Updated $day at $time';
  }

  @override
  String get neverSynced => 'Never updated';

  @override
  String channelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count channels',
      one: '1 channel',
    );
    return '$_temp0';
  }

  @override
  String guideFor(int count) {
    return 'TV guide for $count';
  }

  @override
  String guidePercent(int percent) {
    return 'guide $percent%';
  }

  @override
  String get addSource => 'Add a source';

  @override
  String get watching => 'Watching';

  @override
  String get openLastChannel => 'Open the last channel at start';

  @override
  String get openLastChannelHint => 'Like turning on a TV.';

  @override
  String get pictureSizeSetting => 'Picture size';

  @override
  String get fitFit => 'Fit';

  @override
  String get fitZoom => 'Zoom';

  @override
  String get fitStretch => 'Stretch';

  @override
  String get channelNumbers => 'Channel numbers';

  @override
  String get numbersProvider => 'From the provider';

  @override
  String get numbersSequential => '1, 2, 3…';

  @override
  String get clock24h => '24-hour clock';

  @override
  String get daysToKeep => 'Days of guide to keep';

  @override
  String get daysToKeepHint => 'Fewer days update faster on small devices.';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get updateAutomatically => 'Update sources automatically';

  @override
  String get refreshNever => 'Never';

  @override
  String everyHours(int hours) {
    return 'Every $hours h';
  }

  @override
  String get privacyAndSafety => 'Privacy and safety';

  @override
  String get parentalPin => 'Parental PIN';

  @override
  String get parentalPinHint => 'Locked groups need the PIN.';

  @override
  String get on => 'On';

  @override
  String get off => 'Off';

  @override
  String get about => 'About';

  @override
  String get aboutLine =>
      'Free and open source · No channels included · Licences';

  @override
  String get choosePin => 'Choose a 4-digit PIN';

  @override
  String get enterItAgain => 'Enter it again';

  @override
  String get pinsDiffer => 'The two PINs differ. Nothing changed.';

  @override
  String get pinSaved =>
      'PIN saved. Lock groups from the source\'s groups and filters.';

  @override
  String get enterCurrentPin => 'Enter the current PIN';

  @override
  String get pinRemoved => 'PIN removed and all groups unlocked.';

  @override
  String get changePin => 'Change PIN';

  @override
  String get removePin => 'Remove PIN';

  @override
  String get lockNow => 'Lock now';

  @override
  String get lockedAgain => 'Locked groups hidden again.';
}
