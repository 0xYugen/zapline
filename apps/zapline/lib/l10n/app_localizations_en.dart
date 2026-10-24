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
}
