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
  String get fixDone => 'Done! This channel now has a guide.';

  @override
  String get fixAllMatched =>
      'Done! Every channel you watch has a guide or is marked as having none.';

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
  String get daysToKeep => 'Days of guide';

  @override
  String get daysToKeepHint => 'Fewer days, faster updates.';

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

  @override
  String get tagline =>
      'Your channels, your TV guide. Free, no account, no ads.';

  @override
  String get howDoYouGetChannels => 'How do you get your channels?';

  @override
  String get xtreamChoice => 'Server login (Xtream)';

  @override
  String get xtreamChoiceHint => 'Server address, username and password';

  @override
  String get m3uChoice => 'Playlist link (M3U)';

  @override
  String get m3uChoiceHint => 'A link ending in .m3u or .m3u8';

  @override
  String get restoreChoice => 'Restore a backup';

  @override
  String get restoreChoiceHint =>
      'Bring sources and favourites from another device';

  @override
  String get noChannelsIncluded =>
      'Zapline includes no channels or playlists. It only plays sources you add.';

  @override
  String get errorDuplicate => 'This source is already added.';

  @override
  String get errorUnreachable =>
      'Can\'t reach the server. Check the address and your internet connection.';

  @override
  String get errorLogin =>
      'The server refused the login. Check username and password.';

  @override
  String get errorNotFound => 'Nothing found at that address. Check the link.';

  @override
  String errorGeneric(String error) {
    return 'Couldn\'t connect: $error';
  }

  @override
  String get pairingHint =>
      'Scan the code and paste your details there. No typing on the TV.';

  @override
  String get paste => 'Paste';

  @override
  String get addFirstSource => 'Add your first source';

  @override
  String get xtreamFormHint =>
      'Paste the link your provider sent you: if it contains username and password, they are filled in for you.';

  @override
  String get m3uFormHint =>
      'Paste the playlist link. If your provider gave you a TV guide (EPG) link too, add it below.';

  @override
  String get addSourceHint =>
      'Paste a playlist link or your server address. Xtream links are recognised automatically and the TV guide is set up for you.';

  @override
  String get serverAddress => 'Server address';

  @override
  String get playlistLink => 'Playlist link';

  @override
  String get urlOrServer => 'Playlist URL or server address';

  @override
  String xtreamDetected(String user, String host) {
    return 'Xtream login detected: $user @ $host';
  }

  @override
  String get epgLinkOptional => 'TV guide (EPG) link, optional';

  @override
  String get storedOnDevice =>
      'Saved only on this device, in the system\'s secure storage.';

  @override
  String get connect => 'Connect';

  @override
  String get restoreFromBackup => 'Restore from a backup';

  @override
  String get usernameXtreamOnly => 'Username (Xtream only)';

  @override
  String get password => 'Password';

  @override
  String get passwordXtreamOnly => 'Password (Xtream only)';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get showPassword => 'Show password';

  @override
  String get connecting => 'Connecting…';

  @override
  String get stepLogin => 'Login';

  @override
  String get stepChannels => 'Channels';

  @override
  String stepChannelsCount(int count) {
    return '$count channels';
  }

  @override
  String get stepGuide => 'TV guide';

  @override
  String stepGuideCount(int count) {
    return 'Guide $count';
  }

  @override
  String get stepMatching => 'Matching';

  @override
  String get epgOfferTitle => 'Want a fuller TV guide?';

  @override
  String epgOfferMessage(int count, String country) {
    return '$count channels of this source have no TV guide. A free public EPG for $country can fill most of them.';
  }

  @override
  String get notNow => 'Not now';

  @override
  String get tv => 'TV';

  @override
  String get movies => 'Movies';

  @override
  String get series => 'Series';

  @override
  String get myList => 'My list';

  @override
  String get addToMyList => 'My list';

  @override
  String get inMyList => 'In my list';

  @override
  String get addedToMyList => 'Added to My list';

  @override
  String get removedFromMyList => 'Removed from My list';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get seeAll => 'See all';

  @override
  String get allTitles => 'All';

  @override
  String get categories => 'Categories';

  @override
  String get noTitles => 'Nothing here yet.';

  @override
  String get myListEmpty =>
      'Add films and series to My list to find them here.';

  @override
  String get play => 'Play';

  @override
  String get resume => 'Resume';

  @override
  String get startOver => 'Start over';

  @override
  String get trailer => 'Trailer';

  @override
  String get moreLikeThis => 'More like this';

  @override
  String get director => 'Director';

  @override
  String get cast => 'Cast';

  @override
  String seasonNumber(int number) {
    return 'Season $number';
  }

  @override
  String episodeCode(int season, int episode) {
    return 'S$season·E$episode';
  }

  @override
  String playEpisode(int season, int episode) {
    return 'Play S$season·E$episode';
  }

  @override
  String continueEpisode(int season, int episode) {
    return 'Continue S$season·E$episode';
  }

  @override
  String episodeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count episodes',
      one: '1 episode',
    );
    return '$_temp0';
  }

  @override
  String titleCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titles',
      one: '1 title',
    );
    return '$_temp0';
  }

  @override
  String get noEpisodes => 'No episodes available.';

  @override
  String get detailsUnavailable =>
      'Couldn\'t load the details. Check the connection and try again.';

  @override
  String get retry => 'Try again';

  @override
  String get nextEpisode => 'Next episode';

  @override
  String nextEpisodeIn(int seconds) {
    return 'Next episode in $seconds s';
  }

  @override
  String get rewind10 => 'Back 10 seconds';

  @override
  String get forward10 => 'Forward 10 seconds';

  @override
  String get pause => 'Pause';

  @override
  String hoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get videoUnavailable => 'This title can\'t be played right now.';

  @override
  String get searchMoviesSeries => 'Movies and series';

  @override
  String get searchTooltipVod =>
      'Search channels, programmes, movies and series';

  @override
  String seasonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seasons',
      one: '1 season',
    );
    return '$_temp0';
  }

  @override
  String filterPreviewVod(int shown, int all, int titles) {
    return '$shown of $all categories shown · $titles titles';
  }

  @override
  String get applyFilterEverywhere => 'Apply to TV, movies and series';

  @override
  String get filterAppliedEverywhere =>
      'Filter applied to TV, movies and series';

  @override
  String get channelProgrammeOrTitle => 'Channel, programme, movie or series';

  @override
  String get channelVersion => 'Version (4K, HD…)';

  @override
  String get versionUhd => 'Ultra HD';

  @override
  String get versionFhd => 'Full HD';

  @override
  String get versionHd => 'HD';

  @override
  String get versionSd => 'SD';

  @override
  String get versionOther => 'Other version';

  @override
  String versionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count versions from your list',
      one: '1 version',
    );
    return '$_temp0';
  }

  @override
  String versionPlaying(String quality) {
    return 'Version: $quality';
  }

  @override
  String get rememberVersion => 'Remember for this channel';

  @override
  String get rememberVersionHintBest => 'Otherwise the best picture plays';

  @override
  String get rememberVersionHintSaver => 'Otherwise the HD version plays';

  @override
  String get mergeVersions => 'Merge HD, Full HD and 4K';

  @override
  String get mergeVersionsHint =>
      'One row per channel; hold it to pick the version';

  @override
  String get preferredQuality => 'Quality to play';

  @override
  String get qualityBest => 'The best';

  @override
  String get qualitySaver => 'Save data (HD)';

  @override
  String get filterSaved => 'Saved';

  @override
  String get undo => 'Undo';

  @override
  String get whatToSee => 'What do you want to see?';

  @override
  String get italianOnlyTv => 'Italian channels only';

  @override
  String get italianOnlyMovies => 'Italian movies only';

  @override
  String get italianOnlyShows => 'Italian series only';

  @override
  String get everything => 'Everything';

  @override
  String get pickByHand => 'I pick countries and groups';

  @override
  String get pickByHandHint => 'Switch them on and off below';

  @override
  String get keywordFilterOn => 'Keyword filter on (Advanced)';

  @override
  String tallyTv(int groups, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groups',
      one: '1 group',
    );
    return '$_temp0 · $items channels';
  }

  @override
  String tallyMovies(int groups, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups categories',
      one: '1 category',
    );
    return '$_temp0 · $items movies';
  }

  @override
  String tallyShows(int groups, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups categories',
      one: '1 category',
    );
    return '$_temp0 · $items series';
  }

  @override
  String youWillSeeTv(int groups, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups groups',
      one: '1 group',
    );
    return 'You\'ll see $items channels in $_temp0';
  }

  @override
  String youWillSeeMovies(int groups, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups categories',
      one: '1 category',
    );
    return 'You\'ll see $items movies in $_temp0';
  }

  @override
  String youWillSeeShows(int groups, int items) {
    String _temp0 = intl.Intl.pluralLogic(
      groups,
      locale: localeName,
      other: '$groups categories',
      one: '1 category',
    );
    return 'You\'ll see $items series in $_temp0';
  }

  @override
  String get hideAdult => 'Hide adult content';

  @override
  String hiddenNumber(int count) {
    return '$count hidden';
  }

  @override
  String get byCountry => 'By country';

  @override
  String get otherGroups => 'Other groups';

  @override
  String allHidden(int total) {
    return 'Hidden · $total';
  }

  @override
  String shownOf(int shown, int total) {
    return '$shown of $total shown';
  }

  @override
  String get advancedKeywords => 'Advanced: keyword filter';

  @override
  String allGroupsOf(String name) {
    return 'All of $name';
  }

  @override
  String get allShown => 'All shown';

  @override
  String get allHiddenDone => 'All hidden';

  @override
  String get groupSwitchHint =>
      'The switch shows or hides a group. The lock asks for the PIN to open it.';

  @override
  String get categorySwitchHint => 'The switch shows or hides a category.';

  @override
  String get asksForPin => 'asks for the PIN';

  @override
  String groupShownMsg(String name) {
    return '$name shown';
  }

  @override
  String groupHiddenMsg(String name) {
    return '$name hidden';
  }

  @override
  String guideCoverage(int matched, int total) {
    return '$matched of $total channels have a guide';
  }

  @override
  String guideFailedLine(String error) {
    return 'A guide could not be loaded: $error';
  }

  @override
  String get matchOneByOne => 'Pick the right guide yourself, one at a time';

  @override
  String get guidesInUse => 'Guides in use';

  @override
  String get providerGuide => 'From your provider';

  @override
  String get providerGuideHint => 'Always on';

  @override
  String get providerGuidePerChannel =>
      'Always on · also asked channel by channel';

  @override
  String freeGuideOf(String country) {
    return 'Free · $country';
  }

  @override
  String get freeGuideHint => 'Public guide, fills in what the provider lacks';

  @override
  String get guideLink => 'Your link (XMLTV)';

  @override
  String guideRemovedNamed(String name) {
    return '$name removed';
  }

  @override
  String get addGuide => 'Add a guide';

  @override
  String get addFreeGuide => 'Free guide for a country (recommended)';

  @override
  String get addGuideLink => 'A link of my own (XMLTV)';

  @override
  String get ifSomethingsOff => 'If something\'s off';

  @override
  String get timesWrong => 'The times are wrong';

  @override
  String get timesWrongHint => 'Shift your provider\'s guide earlier or later';

  @override
  String get noShift => 'No shift';

  @override
  String get refreshGuideNow => 'Update the guide now';

  @override
  String get refreshGuideHint => 'It also updates on its own';

  @override
  String matchProgress(int current, int total) {
    return 'Channel $current of $total without a guide';
  }

  @override
  String sureMatches(int count) {
    return '$count near-certain matches';
  }

  @override
  String get sureMatchesHint => 'Same name, only HD or FHD differs';

  @override
  String sureMatchesTaken(int count) {
    return '$count channels now have a guide';
  }

  @override
  String get takeAll => 'Apply';

  @override
  String inGroupNoGuide(String group) {
    return '$group · no guide';
  }

  @override
  String get whichGuide =>
      'Which of these guides is right? Recognise it by what it airs now:';

  @override
  String get noSuggestions =>
      'No guide looks like this channel. Search for it by name:';

  @override
  String get veryLikely => 'VERY LIKELY';

  @override
  String airingNow(String title, String time) {
    return 'Now: $title · until $time';
  }

  @override
  String get nothingAiringNow => 'Nothing airing now';

  @override
  String get searchAnotherGuide => 'Not here? Search another guide';

  @override
  String get noGuideForIt => 'No guide';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String guideLinked(String channel, String guide) {
    return '$channel now uses the guide of $guide';
  }

  @override
  String get versionUhdHint => 'Needs a fast connection';

  @override
  String get versionFhdHint => 'Sharp picture, for most connections';

  @override
  String get versionHdHint => 'Uses less data';

  @override
  String get versionSdHint => 'Lowest data use';

  @override
  String get keepScreenOn => 'Keep the screen on';

  @override
  String get keepScreenOnHint => 'While Zapline is open';

  @override
  String get otherDevices => 'Other devices';

  @override
  String get receiveTitle => 'Receive from another device';

  @override
  String get receiveHint =>
      'Sources, filters, favourites and settings from your phone';

  @override
  String get sendTitle => 'Send to another device';

  @override
  String get sendHint => 'Your whole setup to a TV or PC, scanning its code';

  @override
  String get receiveIntro =>
      'Bring sources, filters, favourites, your list and settings here from your phone. Nothing to type with the remote.';

  @override
  String get receiveStep1 => 'Open Zapline on your phone';

  @override
  String get receiveStep2 => 'Settings → Send to another device';

  @override
  String get receiveStep3 => 'Scan this code';

  @override
  String get scanWithZapline => 'Scan with Zapline';

  @override
  String get sameWifi => 'Both on the same Wi-Fi network.';

  @override
  String get receivedTitle => 'Received';

  @override
  String get downloadingChannels => 'Downloading channels and guide…';

  @override
  String get startWatching => 'Start watching';

  @override
  String get deviceNotFound =>
      'Can\'t reach that device. Are both on the same Wi-Fi, with its code on screen?';

  @override
  String get notAZaplineCode => 'That isn\'t a Zapline code.';

  @override
  String get typeCode => 'Type the code';

  @override
  String get deviceAddress => 'Address shown on the TV';

  @override
  String get sendFailed => 'Sending didn\'t work. Try again.';

  @override
  String sendTo(String name) {
    return 'Send to $name';
  }

  @override
  String get scanTheCode => 'Scan the code on the TV or PC';

  @override
  String get scanTheCodeHint =>
      'On the TV or PC open Zapline → Receive from another device. Same Wi-Fi network.';

  @override
  String get connectedTo => 'Connected. Data stays inside your home network.';

  @override
  String get sendSources => 'Sources and passwords';

  @override
  String sourcesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists',
      one: '1 list',
    );
    return '$_temp0';
  }

  @override
  String get sendFilters => 'Filters, groups and hidden channels';

  @override
  String get sendFiltersHint => 'What each list shows';

  @override
  String get sendFavouritesHint => 'Your favourite channels';

  @override
  String get sendGuideHint => 'Added guides and channels matched by hand';

  @override
  String get sendWatching => 'My list and started titles';

  @override
  String get sendWatchingHint => 'Resume where you left off';

  @override
  String get sendSettings => 'App settings';

  @override
  String get sendSettingsHint => 'Language, quality, channel numbers…';

  @override
  String get sendPinHint => 'Off: you can choose another one there';

  @override
  String get sendReplaces => 'What is already there gets replaced.';

  @override
  String get send => 'Send';

  @override
  String get sentTitle => 'Sent';

  @override
  String sentHint(String name) {
    return '$name is downloading the channels now.';
  }

  @override
  String get done => 'Done';

  @override
  String get castButton => 'Send to TV';

  @override
  String castTo(String title) {
    return 'Send $title to…';
  }

  @override
  String get castSearching => 'Looking for Zapline on your network…';

  @override
  String get castNoneFound =>
      'No Zapline found. Open Zapline on the TV or PC, on the same Wi-Fi network.';

  @override
  String get castZaplineDevice => 'Zapline';

  @override
  String get castOneStream =>
      'This phone stops playing and becomes the remote: still one stream.';

  @override
  String castNoList(String device) {
    return '$device doesn\'t have this list. Send it there from Settings → Send to another device.';
  }

  @override
  String castUnreachable(String device) {
    return 'Can\'t reach $device.';
  }

  @override
  String castFailed(String device) {
    return '$device couldn\'t play it.';
  }

  @override
  String castOnAir(String device) {
    return 'On air on $device';
  }

  @override
  String get castLost => 'Lost contact with the TV';

  @override
  String get castStopped => 'Stopped';

  @override
  String get castWatchHere => 'Watch here';

  @override
  String get castStop => 'Stop on the TV';

  @override
  String pinWait(int seconds) {
    return 'Too many wrong PINs. Try again in $seconds s.';
  }

  @override
  String castLocked(String device) {
    return 'That channel is locked with the PIN on $device.';
  }

  @override
  String get castCodeExpired => 'The code expired. Close and try again.';

  @override
  String castPairTitle(String device) {
    return 'Pair with $device';
  }

  @override
  String castPairHint(String device) {
    return 'Type the code now showing on $device. You only do this once.';
  }

  @override
  String get castPairing => 'Pair a phone';

  @override
  String castPairingAsk(String phone) {
    return '$phone wants to send what it plays to this screen. Type this code on it:';
  }

  @override
  String get castAPhone => 'A phone';

  @override
  String get castPairedPhones => 'Paired phones';

  @override
  String castPairedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count phones can send to this screen',
      one: '1 phone can send to this screen',
    );
    return '$_temp0';
  }

  @override
  String get castUnpairAll => 'Unpair all';

  @override
  String get castUnpaired => 'Phones unpaired';

  @override
  String get noKeystoreTitle => 'Passwords kept in Zapline only';

  @override
  String get noKeystoreHint =>
      'This system has no working keystore, so source passwords are saved in Zapline\'s own data on this device.';
}
