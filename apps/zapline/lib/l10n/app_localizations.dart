import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @allChannels.
  ///
  /// In en, this message translates to:
  /// **'All channels'**
  String get allChannels;

  /// No description provided for @favourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get favourites;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @noGroup.
  ///
  /// In en, this message translates to:
  /// **'No group'**
  String get noGroup;

  /// No description provided for @groups.
  ///
  /// In en, this message translates to:
  /// **'Groups'**
  String get groups;

  /// No description provided for @allGroups.
  ///
  /// In en, this message translates to:
  /// **'All groups'**
  String get allGroups;

  /// No description provided for @findGroup.
  ///
  /// In en, this message translates to:
  /// **'Find a group'**
  String get findGroup;

  /// No description provided for @noChannelsInGroup.
  ///
  /// In en, this message translates to:
  /// **'No channels in this group.'**
  String get noChannelsInGroup;

  /// No description provided for @groupLocked.
  ///
  /// In en, this message translates to:
  /// **'This group is locked'**
  String get groupLocked;

  /// No description provided for @unlockWithPin.
  ///
  /// In en, this message translates to:
  /// **'Unlock with PIN'**
  String get unlockWithPin;

  /// No description provided for @pressOkForPin.
  ///
  /// In en, this message translates to:
  /// **'Press OK to enter the PIN.'**
  String get pressOkForPin;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the PIN'**
  String get enterPin;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN'**
  String get wrongPin;

  /// No description provided for @pinDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get pinDelete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @tvGuide.
  ///
  /// In en, this message translates to:
  /// **'TV guide'**
  String get tvGuide;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @sources.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get sources;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @channels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channels;

  /// No description provided for @guide.
  ///
  /// In en, this message translates to:
  /// **'Guide'**
  String get guide;

  /// No description provided for @liveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get liveTv;

  /// No description provided for @holdOkHint.
  ///
  /// In en, this message translates to:
  /// **'Hold OK on a channel for favourites, hiding and its guide'**
  String get holdOkHint;

  /// No description provided for @noGuideInfo.
  ///
  /// In en, this message translates to:
  /// **'No guide information'**
  String get noGuideInfo;

  /// No description provided for @noGuide.
  ///
  /// In en, this message translates to:
  /// **'No guide'**
  String get noGuide;

  /// No description provided for @noGuideAtTime.
  ///
  /// In en, this message translates to:
  /// **'No guide for this time'**
  String get noGuideAtTime;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @tonightAt.
  ///
  /// In en, this message translates to:
  /// **'Tonight {time}'**
  String tonightAt(String time);

  /// No description provided for @pickTime.
  ///
  /// In en, this message translates to:
  /// **'Pick a time'**
  String get pickTime;

  /// No description provided for @atTime.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String atTime(String time);

  /// No description provided for @thenAt.
  ///
  /// In en, this message translates to:
  /// **'then {time} {title}'**
  String thenAt(String time, String title);

  /// No description provided for @onNow.
  ///
  /// In en, this message translates to:
  /// **'ON NOW'**
  String get onNow;

  /// No description provided for @replay.
  ///
  /// In en, this message translates to:
  /// **'REPLAY'**
  String get replay;

  /// No description provided for @watchLive.
  ///
  /// In en, this message translates to:
  /// **'Watch live'**
  String get watchLive;

  /// No description provided for @noGuideForChannel.
  ///
  /// In en, this message translates to:
  /// **'No guide for this channel.\nYou can link one from Settings → Sources → Fix TV guide.'**
  String get noGuideForChannel;

  /// No description provided for @inTheTvGuide.
  ///
  /// In en, this message translates to:
  /// **'In the TV guide'**
  String get inTheTvGuide;

  /// No description provided for @channelOrProgramme.
  ///
  /// In en, this message translates to:
  /// **'Channel or programme'**
  String get channelOrProgramme;

  /// No description provided for @nothingFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found.'**
  String get nothingFound;

  /// No description provided for @fixTvGuide.
  ///
  /// In en, this message translates to:
  /// **'Fix TV guide'**
  String get fixTvGuide;

  /// No description provided for @fixDone.
  ///
  /// In en, this message translates to:
  /// **'Done. Press Back to return.'**
  String get fixDone;

  /// No description provided for @fixAllMatched.
  ///
  /// In en, this message translates to:
  /// **'Every channel of this source has a guide.'**
  String get fixAllMatched;

  /// No description provided for @fixUnmatched.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel has no guide.} other{{count} channels have no guide.}} Pick one, then choose the matching guide channel.'**
  String fixUnmatched(int count);

  /// No description provided for @pickChannelAbove.
  ///
  /// In en, this message translates to:
  /// **'Pick a channel above.'**
  String get pickChannelAbove;

  /// No description provided for @suggestionsFor.
  ///
  /// In en, this message translates to:
  /// **'Suggestions for {name}'**
  String suggestionsFor(String name);

  /// No description provided for @guideChannels.
  ///
  /// In en, this message translates to:
  /// **'Guide channels'**
  String get guideChannels;

  /// No description provided for @searchTheGuide.
  ///
  /// In en, this message translates to:
  /// **'Search the guide'**
  String get searchTheGuide;

  /// No description provided for @nothingFoundTryAnother.
  ///
  /// In en, this message translates to:
  /// **'Nothing found. Try another name.'**
  String get nothingFoundTryAnother;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup and restore'**
  String get backupTitle;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Save your sources, favourites and guide fixes to a file, or bring them back on a new device. Open the page shown here in a browser on the same network.'**
  String get backupIntro;

  /// No description provided for @backupPrivate.
  ///
  /// In en, this message translates to:
  /// **'The backup file contains your source passwords: keep it private.'**
  String get backupPrivate;

  /// No description provided for @backupOpenOnComputer.
  ///
  /// In en, this message translates to:
  /// **'On a computer on the same Wi-Fi, open'**
  String get backupOpenOnComputer;

  /// No description provided for @backupOpenHere.
  ///
  /// In en, this message translates to:
  /// **'On this computer, open'**
  String get backupOpenHere;

  /// No description provided for @backupCode.
  ///
  /// In en, this message translates to:
  /// **'Code {pin}'**
  String backupCode(String pin);

  /// No description provided for @noLocalNetwork.
  ///
  /// In en, this message translates to:
  /// **'This device is not connected to a local network.'**
  String get noLocalNetwork;

  /// No description provided for @restoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring… {progress}'**
  String restoring(String progress);

  /// No description provided for @pressBackWhenDone.
  ///
  /// In en, this message translates to:
  /// **'Press Back when you are done.'**
  String get pressBackWhenDone;

  /// No description provided for @useYourPhone.
  ///
  /// In en, this message translates to:
  /// **'Use your phone'**
  String get useYourPhone;

  /// No description provided for @backupScan.
  ///
  /// In en, this message translates to:
  /// **'Scan to download a backup or restore one.'**
  String get backupScan;

  /// No description provided for @qrLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code to add a source from your phone'**
  String get qrLabel;

  /// No description provided for @orOpenOnPhone.
  ///
  /// In en, this message translates to:
  /// **'Or open on your phone'**
  String get orOpenOnPhone;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @addToFavourites.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get addToFavourites;

  /// No description provided for @removeFromFavourites.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get removeFromFavourites;

  /// No description provided for @hideChannel.
  ///
  /// In en, this message translates to:
  /// **'Hide this channel'**
  String get hideChannel;

  /// No description provided for @hiddenHint.
  ///
  /// In en, this message translates to:
  /// **'Show it again from the source\'s hidden channels'**
  String get hiddenHint;

  /// No description provided for @fixItsGuide.
  ///
  /// In en, this message translates to:
  /// **'Fix its TV guide'**
  String get fixItsGuide;

  /// No description provided for @freeEpgByCountry.
  ///
  /// In en, this message translates to:
  /// **'Free EPG by country'**
  String get freeEpgByCountry;

  /// No description provided for @freeEpgNote.
  ///
  /// In en, this message translates to:
  /// **'Programme listings from public sources (iptv-epg.org, epgshare01, open-epg.com), free for legal use. Channels are matched by name.'**
  String get freeEpgNote;

  /// No description provided for @findCountry.
  ///
  /// In en, this message translates to:
  /// **'Find a country'**
  String get findCountry;

  /// No description provided for @minutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min left'**
  String minutesLeft(int minutes);

  /// No description provided for @hoursMinutesLeft.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min left'**
  String hoursMinutesLeft(int hours, int minutes);

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageDevice.
  ///
  /// In en, this message translates to:
  /// **'Same as device'**
  String get languageDevice;

  /// No description provided for @watch.
  ///
  /// In en, this message translates to:
  /// **'Watch'**
  String get watch;

  /// No description provided for @fromTheStart.
  ///
  /// In en, this message translates to:
  /// **'From the start'**
  String get fromTheStart;

  /// No description provided for @replayAction.
  ///
  /// In en, this message translates to:
  /// **'Replay'**
  String get replayAction;

  /// No description provided for @remindMe.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get remindMe;

  /// No description provided for @reminderSet.
  ///
  /// In en, this message translates to:
  /// **'Reminder set'**
  String get reminderSet;

  /// No description provided for @watchChannel.
  ///
  /// In en, this message translates to:
  /// **'Watch channel'**
  String get watchChannel;

  /// No description provided for @nextAt.
  ///
  /// In en, this message translates to:
  /// **'Next: {time} {title}'**
  String nextAt(String time, String title);

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue watching'**
  String get continueWatching;

  /// No description provided for @favouritesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No favourites yet.\nHold a channel and choose “Add to favourites”.'**
  String get favouritesEmpty;

  /// No description provided for @reminderNow.
  ///
  /// In en, this message translates to:
  /// **'{title} is starting on {channel}'**
  String reminderNow(String title, String channel);

  /// No description provided for @searchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search channels and programmes'**
  String get searchTooltip;

  /// No description provided for @lessThanAMinute.
  ///
  /// In en, this message translates to:
  /// **'Ending now'**
  String get lessThanAMinute;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
