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

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @previousChannel.
  ///
  /// In en, this message translates to:
  /// **'Previous channel'**
  String get previousChannel;

  /// No description provided for @nextChannel.
  ///
  /// In en, this message translates to:
  /// **'Next channel'**
  String get nextChannel;

  /// No description provided for @backToLive.
  ///
  /// In en, this message translates to:
  /// **'Back to live'**
  String get backToLive;

  /// No description provided for @watchFromStart.
  ///
  /// In en, this message translates to:
  /// **'Watch from the start'**
  String get watchFromStart;

  /// No description provided for @startShort.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get startShort;

  /// No description provided for @liveShort.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveShort;

  /// No description provided for @liveBadge.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveBadge;

  /// No description provided for @catchUpBadge.
  ///
  /// In en, this message translates to:
  /// **'CATCH-UP'**
  String get catchUpBadge;

  /// No description provided for @pictureSize.
  ///
  /// In en, this message translates to:
  /// **'Picture: fit, zoom, stretch'**
  String get pictureSize;

  /// No description provided for @channelList.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get channelList;

  /// No description provided for @programmeInfo.
  ///
  /// In en, this message translates to:
  /// **'Programme info'**
  String get programmeInfo;

  /// No description provided for @audioAndSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Audio and subtitles'**
  String get audioAndSubtitles;

  /// No description provided for @audio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get audio;

  /// No description provided for @subtitles.
  ///
  /// In en, this message translates to:
  /// **'Subtitles'**
  String get subtitles;

  /// No description provided for @subtitlesOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get subtitlesOff;

  /// No description provided for @trackNumber.
  ///
  /// In en, this message translates to:
  /// **'Track {n}'**
  String trackNumber(int n);

  /// No description provided for @noOtherTracks.
  ///
  /// In en, this message translates to:
  /// **'This channel has a single audio track.'**
  String get noOtherTracks;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up or down to change channel'**
  String get swipeHint;

  /// No description provided for @noArchive.
  ///
  /// In en, this message translates to:
  /// **'No archive for this programme'**
  String get noArchive;

  /// No description provided for @channelUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This channel is not available right now'**
  String get channelUnavailable;

  /// No description provided for @archiveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This programme is not available in the archive'**
  String get archiveUnavailable;

  /// No description provided for @tryAnotherChannelKeys.
  ///
  /// In en, this message translates to:
  /// **'Press Up or Down to try another channel.'**
  String get tryAnotherChannelKeys;

  /// No description provided for @tryAnotherChannelTouch.
  ///
  /// In en, this message translates to:
  /// **'Swipe up or down to try another channel.'**
  String get tryAnotherChannelTouch;

  /// No description provided for @pressRightForLive.
  ///
  /// In en, this message translates to:
  /// **'Press Right to go back to live.'**
  String get pressRightForLive;

  /// No description provided for @catchUpLine.
  ///
  /// In en, this message translates to:
  /// **'Catch-up: {title}'**
  String catchUpLine(String title);

  /// No description provided for @nowLine.
  ///
  /// In en, this message translates to:
  /// **'Now: {title}'**
  String nowLine(String title);

  /// No description provided for @prevChannelKey.
  ///
  /// In en, this message translates to:
  /// **'Previous channel (Page Up)'**
  String get prevChannelKey;

  /// No description provided for @nextChannelKey.
  ///
  /// In en, this message translates to:
  /// **'Next channel (Page Down)'**
  String get nextChannelKey;

  /// No description provided for @channelListKey.
  ///
  /// In en, this message translates to:
  /// **'Channel list (Enter)'**
  String get channelListKey;

  /// No description provided for @tuning.
  ///
  /// In en, this message translates to:
  /// **'tuning…'**
  String get tuning;

  /// No description provided for @zapTime.
  ///
  /// In en, this message translates to:
  /// **'zap {ms} ms'**
  String zapTime(int ms);

  /// No description provided for @refreshing.
  ///
  /// In en, this message translates to:
  /// **'Refreshing…'**
  String get refreshing;

  /// No description provided for @refreshed.
  ///
  /// In en, this message translates to:
  /// **'Refreshed.'**
  String get refreshed;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Refresh failed: {error}'**
  String refreshFailed(String error);

  /// No description provided for @enterFullLink.
  ///
  /// In en, this message translates to:
  /// **'Enter a full link, starting with http.'**
  String get enterFullLink;

  /// No description provided for @guideAdded.
  ///
  /// In en, this message translates to:
  /// **'Guide added. Refresh to load it.'**
  String get guideAdded;

  /// No description provided for @loadingFreeEpg.
  ///
  /// In en, this message translates to:
  /// **'Loading the free EPG for {country}…'**
  String loadingFreeEpg(String country);

  /// No description provided for @freeEpgAdded.
  ///
  /// In en, this message translates to:
  /// **'{country} EPG added: TV guide for {matched} of {total} channels.'**
  String freeEpgAdded(String country, int matched, int total);

  /// No description provided for @shiftSaved.
  ///
  /// In en, this message translates to:
  /// **'Guide shift saved. Refresh to apply it.'**
  String get shiftSaved;

  /// No description provided for @noGroupChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels without a group'**
  String get noGroupChannels;

  /// No description provided for @setPinFirst.
  ///
  /// In en, this message translates to:
  /// **'Set a PIN in Settings before locking groups.'**
  String get setPinFirst;

  /// No description provided for @unlockGroup.
  ///
  /// In en, this message translates to:
  /// **'Unlock (no PIN needed)'**
  String get unlockGroup;

  /// No description provided for @lockWithPin.
  ///
  /// In en, this message translates to:
  /// **'Lock with PIN'**
  String get lockWithPin;

  /// No description provided for @followFilterAgain.
  ///
  /// In en, this message translates to:
  /// **'Follow the filter again'**
  String get followFilterAgain;

  /// No description provided for @sectionGuide.
  ///
  /// In en, this message translates to:
  /// **'TV guide (EPG)'**
  String get sectionGuide;

  /// No description provided for @sectionGroups.
  ///
  /// In en, this message translates to:
  /// **'Groups and filters'**
  String get sectionGroups;

  /// No description provided for @sectionHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden channels'**
  String get sectionHidden;

  /// No description provided for @sectionName.
  ///
  /// In en, this message translates to:
  /// **'Name and login'**
  String get sectionName;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved.'**
  String get nameSaved;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @server.
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get server;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @tvGuidesEpg.
  ///
  /// In en, this message translates to:
  /// **'TV guides (EPG)'**
  String get tvGuidesEpg;

  /// No description provided for @epgIntro.
  ///
  /// In en, this message translates to:
  /// **'The EPG from the source itself is loaded automatically. Add more EPG links (XMLTV) here; the first match per channel wins.'**
  String get epgIntro;

  /// No description provided for @addFreeEpgByCountry.
  ///
  /// In en, this message translates to:
  /// **'Add a free EPG by country'**
  String get addFreeEpgByCountry;

  /// No description provided for @freeEpgEntry.
  ///
  /// In en, this message translates to:
  /// **'Free EPG · {country} ({host})'**
  String freeEpgEntry(String country, String host);

  /// No description provided for @guideRemoved.
  ///
  /// In en, this message translates to:
  /// **'Guide removed.'**
  String get guideRemoved;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @addEpgLink.
  ///
  /// In en, this message translates to:
  /// **'Add an EPG link (XMLTV, .xml or .xml.gz)'**
  String get addEpgLink;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @guideTimeShift.
  ///
  /// In en, this message translates to:
  /// **'Guide time shift'**
  String get guideTimeShift;

  /// No description provided for @guideTimeShiftHint.
  ///
  /// In en, this message translates to:
  /// **'For guides that show the wrong times.'**
  String get guideTimeShiftHint;

  /// No description provided for @refreshNow.
  ///
  /// In en, this message translates to:
  /// **'Refresh now'**
  String get refreshNow;

  /// No description provided for @showTheseGroups.
  ///
  /// In en, this message translates to:
  /// **'Show these groups'**
  String get showTheseGroups;

  /// No description provided for @filterHelp.
  ///
  /// In en, this message translates to:
  /// **'Words separated by commas. IT matches \"IT | Sport\" but not \"Hits\"; ital* matches Italia and Italy; IT| matches that exact text. Hiding always wins.'**
  String get filterHelp;

  /// No description provided for @presetItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian only'**
  String get presetItalian;

  /// No description provided for @presetAdult.
  ///
  /// In en, this message translates to:
  /// **'Hide adult'**
  String get presetAdult;

  /// No description provided for @presetVod.
  ///
  /// In en, this message translates to:
  /// **'Hide VOD and series'**
  String get presetVod;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @showOnlyGroupsWith.
  ///
  /// In en, this message translates to:
  /// **'Show only groups with (empty = all)'**
  String get showOnlyGroupsWith;

  /// No description provided for @hideGroupsWith.
  ///
  /// In en, this message translates to:
  /// **'Hide groups with'**
  String get hideGroupsWith;

  /// No description provided for @filterPreview.
  ///
  /// In en, this message translates to:
  /// **'Shows {groups} of {all} groups · {channels} channels'**
  String filterPreview(int groups, int all, int channels);

  /// No description provided for @filterApplied.
  ///
  /// In en, this message translates to:
  /// **'Filter applied.'**
  String get filterApplied;

  /// No description provided for @applyFilter.
  ///
  /// In en, this message translates to:
  /// **'Apply filter'**
  String get applyFilter;

  /// No description provided for @applied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get applied;

  /// No description provided for @groupsHelp.
  ///
  /// In en, this message translates to:
  /// **'Tap shows or hides a group. Hold to lock it with the PIN or to make it follow the filter again.'**
  String get groupsHelp;

  /// No description provided for @groupState.
  ///
  /// In en, this message translates to:
  /// **'{count} · {state, select, hidden{hidden} other{shown}}{by, select, filter{ by filter} other{}}'**
  String groupState(int count, String state, String by);

  /// No description provided for @noHiddenChannels.
  ///
  /// In en, this message translates to:
  /// **'No hidden channels. Hold a channel and choose “Hide this channel” to hide it.'**
  String get noHiddenChannels;

  /// No description provided for @showAgain.
  ///
  /// In en, this message translates to:
  /// **'Show again'**
  String get showAgain;

  /// No description provided for @refreshResult.
  ///
  /// In en, this message translates to:
  /// **'{channels} channels, {programmes} guide entries'**
  String refreshResult(int channels, int programmes);

  /// No description provided for @refreshGuideFailed.
  ///
  /// In en, this message translates to:
  /// **'Channels updated, guide failed ({errors})'**
  String refreshGuideFailed(String errors);

  /// No description provided for @removeSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String removeSourceTitle(String name);

  /// No description provided for @removeSourceMessage.
  ///
  /// In en, this message translates to:
  /// **'Its channels, favourites and guide links go too. You can add it again later.'**
  String get removeSourceMessage;

  /// No description provided for @removeSource.
  ///
  /// In en, this message translates to:
  /// **'Remove this source'**
  String get removeSource;

  /// No description provided for @channelsWithoutGuide.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel still has no TV guide.} other{{count} channels still have no TV guide.}}'**
  String channelsWithoutGuide(int count);

  /// No description provided for @addFreeEpgFor.
  ///
  /// In en, this message translates to:
  /// **'Add the free EPG for {country}'**
  String addFreeEpgFor(String country);

  /// No description provided for @addFreeEpg.
  ///
  /// In en, this message translates to:
  /// **'Add a free EPG'**
  String get addFreeEpg;

  /// No description provided for @matchThem.
  ///
  /// In en, this message translates to:
  /// **'Match them'**
  String get matchThem;

  /// No description provided for @guideFromSource.
  ///
  /// In en, this message translates to:
  /// **'From the source'**
  String get guideFromSource;

  /// No description provided for @freeEpgShort.
  ///
  /// In en, this message translates to:
  /// **'free EPG {countries}'**
  String freeEpgShort(String countries);

  /// No description provided for @extraGuides.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 more guide} other{{count} more guides}}'**
  String extraGuides(int count);

  /// No description provided for @shiftedBy.
  ///
  /// In en, this message translates to:
  /// **'shifted {value}'**
  String shiftedBy(String value);

  /// No description provided for @filterOn.
  ///
  /// In en, this message translates to:
  /// **'Filter on'**
  String get filterOn;

  /// No description provided for @groupsShown.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {all} groups shown'**
  String groupsShown(int shown, int all);

  /// No description provided for @hiddenCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{None} =1{1 hidden} other{{count} hidden}}'**
  String hiddenCount(int count);

  /// No description provided for @syncingProgress.
  ///
  /// In en, this message translates to:
  /// **'Updating… {progress}'**
  String syncingProgress(String progress);

  /// No description provided for @epgFailed.
  ///
  /// In en, this message translates to:
  /// **'EPG could not be loaded: {errors}'**
  String epgFailed(String errors);

  /// No description provided for @epgEmptyPerChannel.
  ///
  /// In en, this message translates to:
  /// **'The source sent an empty EPG; what\'s on now is asked channel by channel.'**
  String get epgEmptyPerChannel;

  /// No description provided for @epgEmpty.
  ///
  /// In en, this message translates to:
  /// **'The source sent an empty EPG. Add a free EPG or a link.'**
  String get epgEmpty;

  /// No description provided for @updatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated {day} at {time}'**
  String updatedAt(String day, String time);

  /// No description provided for @neverSynced.
  ///
  /// In en, this message translates to:
  /// **'Never updated'**
  String get neverSynced;

  /// No description provided for @channelCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 channel} other{{count} channels}}'**
  String channelCount(int count);

  /// No description provided for @guideFor.
  ///
  /// In en, this message translates to:
  /// **'TV guide for {count}'**
  String guideFor(int count);

  /// No description provided for @guidePercent.
  ///
  /// In en, this message translates to:
  /// **'guide {percent}%'**
  String guidePercent(int percent);

  /// No description provided for @addSource.
  ///
  /// In en, this message translates to:
  /// **'Add a source'**
  String get addSource;

  /// No description provided for @watching.
  ///
  /// In en, this message translates to:
  /// **'Watching'**
  String get watching;

  /// No description provided for @openLastChannel.
  ///
  /// In en, this message translates to:
  /// **'Open the last channel at start'**
  String get openLastChannel;

  /// No description provided for @openLastChannelHint.
  ///
  /// In en, this message translates to:
  /// **'Like turning on a TV.'**
  String get openLastChannelHint;

  /// No description provided for @pictureSizeSetting.
  ///
  /// In en, this message translates to:
  /// **'Picture size'**
  String get pictureSizeSetting;

  /// No description provided for @fitFit.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get fitFit;

  /// No description provided for @fitZoom.
  ///
  /// In en, this message translates to:
  /// **'Zoom'**
  String get fitZoom;

  /// No description provided for @fitStretch.
  ///
  /// In en, this message translates to:
  /// **'Stretch'**
  String get fitStretch;

  /// No description provided for @channelNumbers.
  ///
  /// In en, this message translates to:
  /// **'Channel numbers'**
  String get channelNumbers;

  /// No description provided for @numbersProvider.
  ///
  /// In en, this message translates to:
  /// **'From the provider'**
  String get numbersProvider;

  /// No description provided for @numbersSequential.
  ///
  /// In en, this message translates to:
  /// **'1, 2, 3…'**
  String get numbersSequential;

  /// No description provided for @clock24h.
  ///
  /// In en, this message translates to:
  /// **'24-hour clock'**
  String get clock24h;

  /// No description provided for @daysToKeep.
  ///
  /// In en, this message translates to:
  /// **'Days of guide to keep'**
  String get daysToKeep;

  /// No description provided for @daysToKeepHint.
  ///
  /// In en, this message translates to:
  /// **'Fewer days update faster on small devices.'**
  String get daysToKeepHint;

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// No description provided for @updateAutomatically.
  ///
  /// In en, this message translates to:
  /// **'Update sources automatically'**
  String get updateAutomatically;

  /// No description provided for @refreshNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get refreshNever;

  /// No description provided for @everyHours.
  ///
  /// In en, this message translates to:
  /// **'Every {hours} h'**
  String everyHours(int hours);

  /// No description provided for @privacyAndSafety.
  ///
  /// In en, this message translates to:
  /// **'Privacy and safety'**
  String get privacyAndSafety;

  /// No description provided for @parentalPin.
  ///
  /// In en, this message translates to:
  /// **'Parental PIN'**
  String get parentalPin;

  /// No description provided for @parentalPinHint.
  ///
  /// In en, this message translates to:
  /// **'Locked groups need the PIN.'**
  String get parentalPinHint;

  /// No description provided for @on.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get on;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutLine.
  ///
  /// In en, this message translates to:
  /// **'Free and open source · No channels included · Licences'**
  String get aboutLine;

  /// No description provided for @choosePin.
  ///
  /// In en, this message translates to:
  /// **'Choose a 4-digit PIN'**
  String get choosePin;

  /// No description provided for @enterItAgain.
  ///
  /// In en, this message translates to:
  /// **'Enter it again'**
  String get enterItAgain;

  /// No description provided for @pinsDiffer.
  ///
  /// In en, this message translates to:
  /// **'The two PINs differ. Nothing changed.'**
  String get pinsDiffer;

  /// No description provided for @pinSaved.
  ///
  /// In en, this message translates to:
  /// **'PIN saved. Lock groups from the source\'s groups and filters.'**
  String get pinSaved;

  /// No description provided for @enterCurrentPin.
  ///
  /// In en, this message translates to:
  /// **'Enter the current PIN'**
  String get enterCurrentPin;

  /// No description provided for @pinRemoved.
  ///
  /// In en, this message translates to:
  /// **'PIN removed and all groups unlocked.'**
  String get pinRemoved;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get changePin;

  /// No description provided for @removePin.
  ///
  /// In en, this message translates to:
  /// **'Remove PIN'**
  String get removePin;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @lockedAgain.
  ///
  /// In en, this message translates to:
  /// **'Locked groups hidden again.'**
  String get lockedAgain;
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
