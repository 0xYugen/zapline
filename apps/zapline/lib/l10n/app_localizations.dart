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
  /// **'Done! This channel now has a guide.'**
  String get fixDone;

  /// No description provided for @fixAllMatched.
  ///
  /// In en, this message translates to:
  /// **'Done! Every channel you watch has a guide or is marked as having none.'**
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
  /// **'Days of guide'**
  String get daysToKeep;

  /// No description provided for @daysToKeepHint.
  ///
  /// In en, this message translates to:
  /// **'Fewer days, faster updates.'**
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

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your channels, your TV guide. Free, no account, no ads.'**
  String get tagline;

  /// No description provided for @howDoYouGetChannels.
  ///
  /// In en, this message translates to:
  /// **'How do you get your channels?'**
  String get howDoYouGetChannels;

  /// No description provided for @xtreamChoice.
  ///
  /// In en, this message translates to:
  /// **'Server login (Xtream)'**
  String get xtreamChoice;

  /// No description provided for @xtreamChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Server address, username and password'**
  String get xtreamChoiceHint;

  /// No description provided for @m3uChoice.
  ///
  /// In en, this message translates to:
  /// **'Playlist link (M3U)'**
  String get m3uChoice;

  /// No description provided for @m3uChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'A link ending in .m3u or .m3u8'**
  String get m3uChoiceHint;

  /// No description provided for @restoreChoice.
  ///
  /// In en, this message translates to:
  /// **'Restore a backup'**
  String get restoreChoice;

  /// No description provided for @restoreChoiceHint.
  ///
  /// In en, this message translates to:
  /// **'Bring sources and favourites from another device'**
  String get restoreChoiceHint;

  /// No description provided for @noChannelsIncluded.
  ///
  /// In en, this message translates to:
  /// **'Zapline includes no channels or playlists. It only plays sources you add.'**
  String get noChannelsIncluded;

  /// No description provided for @errorDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This source is already added.'**
  String get errorDuplicate;

  /// No description provided for @errorUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check the address and your internet connection.'**
  String get errorUnreachable;

  /// No description provided for @errorLogin.
  ///
  /// In en, this message translates to:
  /// **'The server refused the login. Check username and password.'**
  String get errorLogin;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Nothing found at that address. Check the link.'**
  String get errorNotFound;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t connect: {error}'**
  String errorGeneric(String error);

  /// No description provided for @pairingHint.
  ///
  /// In en, this message translates to:
  /// **'With the phone\'s camera, type your playlist details there; with Zapline on the phone (Send to another device), copy your whole setup.'**
  String get pairingHint;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @addFirstSource.
  ///
  /// In en, this message translates to:
  /// **'Add your first source'**
  String get addFirstSource;

  /// No description provided for @xtreamFormHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the link your provider sent you: if it contains username and password, they are filled in for you.'**
  String get xtreamFormHint;

  /// No description provided for @m3uFormHint.
  ///
  /// In en, this message translates to:
  /// **'Paste the playlist link. If your provider gave you a TV guide (EPG) link too, add it below.'**
  String get m3uFormHint;

  /// No description provided for @addSourceHint.
  ///
  /// In en, this message translates to:
  /// **'Paste a playlist link or your server address. Xtream links are recognised automatically and the TV guide is set up for you.'**
  String get addSourceHint;

  /// No description provided for @serverAddress.
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddress;

  /// No description provided for @playlistLink.
  ///
  /// In en, this message translates to:
  /// **'Playlist link'**
  String get playlistLink;

  /// No description provided for @urlOrServer.
  ///
  /// In en, this message translates to:
  /// **'Playlist URL or server address'**
  String get urlOrServer;

  /// No description provided for @xtreamDetected.
  ///
  /// In en, this message translates to:
  /// **'Xtream login detected: {user} @ {host}'**
  String xtreamDetected(String user, String host);

  /// No description provided for @epgLinkOptional.
  ///
  /// In en, this message translates to:
  /// **'TV guide (EPG) link, optional'**
  String get epgLinkOptional;

  /// No description provided for @storedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Saved only on this device, in the system\'s secure storage.'**
  String get storedOnDevice;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get restoreFromBackup;

  /// No description provided for @usernameXtreamOnly.
  ///
  /// In en, this message translates to:
  /// **'Username (Xtream only)'**
  String get usernameXtreamOnly;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @passwordXtreamOnly.
  ///
  /// In en, this message translates to:
  /// **'Password (Xtream only)'**
  String get passwordXtreamOnly;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get connecting;

  /// No description provided for @stepLogin.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get stepLogin;

  /// No description provided for @stepChannels.
  ///
  /// In en, this message translates to:
  /// **'Channels'**
  String get stepChannels;

  /// No description provided for @stepChannelsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} channels'**
  String stepChannelsCount(int count);

  /// No description provided for @stepGuide.
  ///
  /// In en, this message translates to:
  /// **'TV guide'**
  String get stepGuide;

  /// No description provided for @stepGuideCount.
  ///
  /// In en, this message translates to:
  /// **'Guide {count}'**
  String stepGuideCount(int count);

  /// No description provided for @stepMatching.
  ///
  /// In en, this message translates to:
  /// **'Matching'**
  String get stepMatching;

  /// No description provided for @epgOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Want a fuller TV guide?'**
  String get epgOfferTitle;

  /// No description provided for @epgOfferMessage.
  ///
  /// In en, this message translates to:
  /// **'{count} channels of this source have no TV guide. A free public EPG for {country} can fill most of them.'**
  String epgOfferMessage(int count, String country);

  /// No description provided for @notNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

  /// No description provided for @tv.
  ///
  /// In en, this message translates to:
  /// **'TV'**
  String get tv;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @myList.
  ///
  /// In en, this message translates to:
  /// **'My list'**
  String get myList;

  /// No description provided for @addToMyList.
  ///
  /// In en, this message translates to:
  /// **'My list'**
  String get addToMyList;

  /// No description provided for @inMyList.
  ///
  /// In en, this message translates to:
  /// **'In my list'**
  String get inMyList;

  /// No description provided for @addedToMyList.
  ///
  /// In en, this message translates to:
  /// **'Added to My list'**
  String get addedToMyList;

  /// No description provided for @removedFromMyList.
  ///
  /// In en, this message translates to:
  /// **'Removed from My list'**
  String get removedFromMyList;

  /// No description provided for @recentlyAdded.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get recentlyAdded;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @allTitles.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allTitles;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @noTitles.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get noTitles;

  /// No description provided for @myListEmpty.
  ///
  /// In en, this message translates to:
  /// **'Add films and series to My list to find them here.'**
  String get myListEmpty;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @trailer.
  ///
  /// In en, this message translates to:
  /// **'Trailer'**
  String get trailer;

  /// No description provided for @moreLikeThis.
  ///
  /// In en, this message translates to:
  /// **'More like this'**
  String get moreLikeThis;

  /// No description provided for @director.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get director;

  /// No description provided for @cast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get cast;

  /// No description provided for @seasonNumber.
  ///
  /// In en, this message translates to:
  /// **'Season {number}'**
  String seasonNumber(int number);

  /// No description provided for @episodeCode.
  ///
  /// In en, this message translates to:
  /// **'S{season}·E{episode}'**
  String episodeCode(int season, int episode);

  /// No description provided for @playEpisode.
  ///
  /// In en, this message translates to:
  /// **'Play S{season}·E{episode}'**
  String playEpisode(int season, int episode);

  /// No description provided for @continueEpisode.
  ///
  /// In en, this message translates to:
  /// **'Continue S{season}·E{episode}'**
  String continueEpisode(int season, int episode);

  /// No description provided for @episodeCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 episode} other{{count} episodes}}'**
  String episodeCount(int count);

  /// No description provided for @titleCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 title} other{{count} titles}}'**
  String titleCount(int count);

  /// No description provided for @noEpisodes.
  ///
  /// In en, this message translates to:
  /// **'No episodes available.'**
  String get noEpisodes;

  /// No description provided for @detailsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the details. Check the connection and try again.'**
  String get detailsUnavailable;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @nextEpisode.
  ///
  /// In en, this message translates to:
  /// **'Next episode'**
  String get nextEpisode;

  /// No description provided for @nextEpisodeIn.
  ///
  /// In en, this message translates to:
  /// **'Next episode in {seconds} s'**
  String nextEpisodeIn(int seconds);

  /// No description provided for @rewind10.
  ///
  /// In en, this message translates to:
  /// **'Back 10 seconds'**
  String get rewind10;

  /// No description provided for @forward10.
  ///
  /// In en, this message translates to:
  /// **'Forward 10 seconds'**
  String get forward10;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @hoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String hoursMinutes(int hours, int minutes);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @videoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This title can\'t be played right now.'**
  String get videoUnavailable;

  /// No description provided for @searchMoviesSeries.
  ///
  /// In en, this message translates to:
  /// **'Movies and series'**
  String get searchMoviesSeries;

  /// No description provided for @searchTooltipVod.
  ///
  /// In en, this message translates to:
  /// **'Search channels, programmes, movies and series'**
  String get searchTooltipVod;

  /// No description provided for @seasonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 season} other{{count} seasons}}'**
  String seasonCount(int count);

  /// No description provided for @filterPreviewVod.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {all} categories shown · {titles} titles'**
  String filterPreviewVod(int shown, int all, int titles);

  /// No description provided for @applyFilterEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Apply to TV, movies and series'**
  String get applyFilterEverywhere;

  /// No description provided for @filterAppliedEverywhere.
  ///
  /// In en, this message translates to:
  /// **'Filter applied to TV, movies and series'**
  String get filterAppliedEverywhere;

  /// No description provided for @channelProgrammeOrTitle.
  ///
  /// In en, this message translates to:
  /// **'Channel, programme, movie or series'**
  String get channelProgrammeOrTitle;

  /// No description provided for @channelVersion.
  ///
  /// In en, this message translates to:
  /// **'Version (4K, HD…)'**
  String get channelVersion;

  /// No description provided for @versionUhd.
  ///
  /// In en, this message translates to:
  /// **'Ultra HD'**
  String get versionUhd;

  /// No description provided for @versionFhd.
  ///
  /// In en, this message translates to:
  /// **'Full HD'**
  String get versionFhd;

  /// No description provided for @versionHd.
  ///
  /// In en, this message translates to:
  /// **'HD'**
  String get versionHd;

  /// No description provided for @versionSd.
  ///
  /// In en, this message translates to:
  /// **'SD'**
  String get versionSd;

  /// No description provided for @versionOther.
  ///
  /// In en, this message translates to:
  /// **'Other version'**
  String get versionOther;

  /// No description provided for @versionCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 version} other{{count} versions from your list}}'**
  String versionCount(int count);

  /// No description provided for @versionPlaying.
  ///
  /// In en, this message translates to:
  /// **'Version: {quality}'**
  String versionPlaying(String quality);

  /// No description provided for @rememberVersion.
  ///
  /// In en, this message translates to:
  /// **'Remember for this channel'**
  String get rememberVersion;

  /// No description provided for @rememberVersionHintBest.
  ///
  /// In en, this message translates to:
  /// **'Otherwise the best picture plays'**
  String get rememberVersionHintBest;

  /// No description provided for @rememberVersionHintSaver.
  ///
  /// In en, this message translates to:
  /// **'Otherwise the HD version plays'**
  String get rememberVersionHintSaver;

  /// No description provided for @mergeVersions.
  ///
  /// In en, this message translates to:
  /// **'Merge HD, Full HD and 4K'**
  String get mergeVersions;

  /// No description provided for @mergeVersionsHint.
  ///
  /// In en, this message translates to:
  /// **'One row per channel; hold it to pick the version'**
  String get mergeVersionsHint;

  /// No description provided for @preferredQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality to play'**
  String get preferredQuality;

  /// No description provided for @qualityBest.
  ///
  /// In en, this message translates to:
  /// **'The best'**
  String get qualityBest;

  /// No description provided for @qualitySaver.
  ///
  /// In en, this message translates to:
  /// **'Save data (HD)'**
  String get qualitySaver;

  /// No description provided for @filterSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get filterSaved;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @whatToSee.
  ///
  /// In en, this message translates to:
  /// **'What do you want to see?'**
  String get whatToSee;

  /// No description provided for @italianOnlyTv.
  ///
  /// In en, this message translates to:
  /// **'Italian channels only'**
  String get italianOnlyTv;

  /// No description provided for @italianOnlyMovies.
  ///
  /// In en, this message translates to:
  /// **'Italian movies only'**
  String get italianOnlyMovies;

  /// No description provided for @italianOnlyShows.
  ///
  /// In en, this message translates to:
  /// **'Italian series only'**
  String get italianOnlyShows;

  /// No description provided for @everything.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get everything;

  /// No description provided for @pickByHand.
  ///
  /// In en, this message translates to:
  /// **'I pick countries and groups'**
  String get pickByHand;

  /// No description provided for @pickByHandHint.
  ///
  /// In en, this message translates to:
  /// **'Switch them on and off below'**
  String get pickByHandHint;

  /// No description provided for @keywordFilterOn.
  ///
  /// In en, this message translates to:
  /// **'Keyword filter on (Advanced)'**
  String get keywordFilterOn;

  /// No description provided for @tallyTv.
  ///
  /// In en, this message translates to:
  /// **'{groups, plural, =1{1 group} other{{groups} groups}} · {items} channels'**
  String tallyTv(int groups, int items);

  /// No description provided for @tallyMovies.
  ///
  /// In en, this message translates to:
  /// **'{groups, plural, =1{1 category} other{{groups} categories}} · {items} movies'**
  String tallyMovies(int groups, int items);

  /// No description provided for @tallyShows.
  ///
  /// In en, this message translates to:
  /// **'{groups, plural, =1{1 category} other{{groups} categories}} · {items} series'**
  String tallyShows(int groups, int items);

  /// No description provided for @youWillSeeTv.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see {items} channels in {groups, plural, =1{1 group} other{{groups} groups}}'**
  String youWillSeeTv(int groups, int items);

  /// No description provided for @youWillSeeMovies.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see {items} movies in {groups, plural, =1{1 category} other{{groups} categories}}'**
  String youWillSeeMovies(int groups, int items);

  /// No description provided for @youWillSeeShows.
  ///
  /// In en, this message translates to:
  /// **'You\'ll see {items} series in {groups, plural, =1{1 category} other{{groups} categories}}'**
  String youWillSeeShows(int groups, int items);

  /// No description provided for @hideAdult.
  ///
  /// In en, this message translates to:
  /// **'Hide adult content'**
  String get hideAdult;

  /// No description provided for @hiddenNumber.
  ///
  /// In en, this message translates to:
  /// **'{count} hidden'**
  String hiddenNumber(int count);

  /// No description provided for @byCountry.
  ///
  /// In en, this message translates to:
  /// **'By country'**
  String get byCountry;

  /// No description provided for @otherGroups.
  ///
  /// In en, this message translates to:
  /// **'Other groups'**
  String get otherGroups;

  /// No description provided for @allHidden.
  ///
  /// In en, this message translates to:
  /// **'Hidden · {total}'**
  String allHidden(int total);

  /// No description provided for @shownOf.
  ///
  /// In en, this message translates to:
  /// **'{shown} of {total} shown'**
  String shownOf(int shown, int total);

  /// No description provided for @advancedKeywords.
  ///
  /// In en, this message translates to:
  /// **'Advanced: keyword filter'**
  String get advancedKeywords;

  /// No description provided for @allGroupsOf.
  ///
  /// In en, this message translates to:
  /// **'All of {name}'**
  String allGroupsOf(String name);

  /// No description provided for @allShown.
  ///
  /// In en, this message translates to:
  /// **'All shown'**
  String get allShown;

  /// No description provided for @allHiddenDone.
  ///
  /// In en, this message translates to:
  /// **'All hidden'**
  String get allHiddenDone;

  /// No description provided for @groupSwitchHint.
  ///
  /// In en, this message translates to:
  /// **'The switch shows or hides a group. The lock asks for the PIN to open it.'**
  String get groupSwitchHint;

  /// No description provided for @categorySwitchHint.
  ///
  /// In en, this message translates to:
  /// **'The switch shows or hides a category.'**
  String get categorySwitchHint;

  /// No description provided for @asksForPin.
  ///
  /// In en, this message translates to:
  /// **'asks for the PIN'**
  String get asksForPin;

  /// No description provided for @groupShownMsg.
  ///
  /// In en, this message translates to:
  /// **'{name} shown'**
  String groupShownMsg(String name);

  /// No description provided for @groupHiddenMsg.
  ///
  /// In en, this message translates to:
  /// **'{name} hidden'**
  String groupHiddenMsg(String name);

  /// No description provided for @guideCoverage.
  ///
  /// In en, this message translates to:
  /// **'{matched} of {total} channels have a guide'**
  String guideCoverage(int matched, int total);

  /// No description provided for @guideFailedLine.
  ///
  /// In en, this message translates to:
  /// **'A guide could not be loaded: {error}'**
  String guideFailedLine(String error);

  /// No description provided for @matchOneByOne.
  ///
  /// In en, this message translates to:
  /// **'Pick the right guide yourself, one at a time'**
  String get matchOneByOne;

  /// No description provided for @guidesInUse.
  ///
  /// In en, this message translates to:
  /// **'Guides in use'**
  String get guidesInUse;

  /// No description provided for @providerGuide.
  ///
  /// In en, this message translates to:
  /// **'From your provider'**
  String get providerGuide;

  /// No description provided for @providerGuideHint.
  ///
  /// In en, this message translates to:
  /// **'Always on'**
  String get providerGuideHint;

  /// No description provided for @providerGuidePerChannel.
  ///
  /// In en, this message translates to:
  /// **'Always on · also asked channel by channel'**
  String get providerGuidePerChannel;

  /// No description provided for @freeGuideOf.
  ///
  /// In en, this message translates to:
  /// **'Free · {country}'**
  String freeGuideOf(String country);

  /// No description provided for @freeGuideHint.
  ///
  /// In en, this message translates to:
  /// **'Public guide, fills in what the provider lacks'**
  String get freeGuideHint;

  /// No description provided for @guideLink.
  ///
  /// In en, this message translates to:
  /// **'Your link (XMLTV)'**
  String get guideLink;

  /// No description provided for @guideRemovedNamed.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String guideRemovedNamed(String name);

  /// No description provided for @addGuide.
  ///
  /// In en, this message translates to:
  /// **'Add a guide'**
  String get addGuide;

  /// No description provided for @addFreeGuide.
  ///
  /// In en, this message translates to:
  /// **'Free guide for a country (recommended)'**
  String get addFreeGuide;

  /// No description provided for @addGuideLink.
  ///
  /// In en, this message translates to:
  /// **'A link of my own (XMLTV)'**
  String get addGuideLink;

  /// No description provided for @ifSomethingsOff.
  ///
  /// In en, this message translates to:
  /// **'If something\'s off'**
  String get ifSomethingsOff;

  /// No description provided for @timesWrong.
  ///
  /// In en, this message translates to:
  /// **'The times are wrong'**
  String get timesWrong;

  /// No description provided for @timesWrongHint.
  ///
  /// In en, this message translates to:
  /// **'Shift one guide or all of them earlier or later'**
  String get timesWrongHint;

  /// No description provided for @whichGuideToShift.
  ///
  /// In en, this message translates to:
  /// **'Which guide do you want to shift?'**
  String get whichGuideToShift;

  /// No description provided for @allGuides.
  ///
  /// In en, this message translates to:
  /// **'All guides'**
  String get allGuides;

  /// No description provided for @shiftTimes.
  ///
  /// In en, this message translates to:
  /// **'Shift times'**
  String get shiftTimes;

  /// No description provided for @shiftBy.
  ///
  /// In en, this message translates to:
  /// **'Shift by…'**
  String get shiftBy;

  /// No description provided for @noShift.
  ///
  /// In en, this message translates to:
  /// **'No shift'**
  String get noShift;

  /// No description provided for @refreshGuideNow.
  ///
  /// In en, this message translates to:
  /// **'Update the guide now'**
  String get refreshGuideNow;

  /// No description provided for @refreshGuideHint.
  ///
  /// In en, this message translates to:
  /// **'It also updates on its own'**
  String get refreshGuideHint;

  /// No description provided for @matchProgress.
  ///
  /// In en, this message translates to:
  /// **'Channel {current} of {total} without a guide'**
  String matchProgress(int current, int total);

  /// No description provided for @sureMatches.
  ///
  /// In en, this message translates to:
  /// **'{count} near-certain matches'**
  String sureMatches(int count);

  /// No description provided for @sureMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Same name, only HD or FHD differs'**
  String get sureMatchesHint;

  /// No description provided for @sureMatchesTaken.
  ///
  /// In en, this message translates to:
  /// **'{count} channels now have a guide'**
  String sureMatchesTaken(int count);

  /// No description provided for @takeAll.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get takeAll;

  /// No description provided for @inGroupNoGuide.
  ///
  /// In en, this message translates to:
  /// **'{group} · no guide'**
  String inGroupNoGuide(String group);

  /// No description provided for @whichGuide.
  ///
  /// In en, this message translates to:
  /// **'Which of these guides is right? Recognise it by what it airs now:'**
  String get whichGuide;

  /// No description provided for @noSuggestions.
  ///
  /// In en, this message translates to:
  /// **'No guide looks like this channel. Search for it by name:'**
  String get noSuggestions;

  /// No description provided for @veryLikely.
  ///
  /// In en, this message translates to:
  /// **'VERY LIKELY'**
  String get veryLikely;

  /// No description provided for @airingNow.
  ///
  /// In en, this message translates to:
  /// **'Now: {title} · until {time}'**
  String airingNow(String title, String time);

  /// No description provided for @nothingAiringNow.
  ///
  /// In en, this message translates to:
  /// **'Nothing airing now'**
  String get nothingAiringNow;

  /// No description provided for @searchAnotherGuide.
  ///
  /// In en, this message translates to:
  /// **'Not here? Search another guide'**
  String get searchAnotherGuide;

  /// No description provided for @noGuideForIt.
  ///
  /// In en, this message translates to:
  /// **'No guide'**
  String get noGuideForIt;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @guideLinked.
  ///
  /// In en, this message translates to:
  /// **'{channel} now uses the guide of {guide}'**
  String guideLinked(String channel, String guide);

  /// No description provided for @versionUhdHint.
  ///
  /// In en, this message translates to:
  /// **'Needs a fast connection'**
  String get versionUhdHint;

  /// No description provided for @versionFhdHint.
  ///
  /// In en, this message translates to:
  /// **'Sharp picture, for most connections'**
  String get versionFhdHint;

  /// No description provided for @versionHdHint.
  ///
  /// In en, this message translates to:
  /// **'Uses less data'**
  String get versionHdHint;

  /// No description provided for @versionSdHint.
  ///
  /// In en, this message translates to:
  /// **'Lowest data use'**
  String get versionSdHint;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on'**
  String get keepScreenOn;

  /// No description provided for @keepScreenOnHint.
  ///
  /// In en, this message translates to:
  /// **'While Zapline is open'**
  String get keepScreenOnHint;

  /// No description provided for @otherDevices.
  ///
  /// In en, this message translates to:
  /// **'Other devices'**
  String get otherDevices;

  /// No description provided for @receiveTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive from another device'**
  String get receiveTitle;

  /// No description provided for @receiveHint.
  ///
  /// In en, this message translates to:
  /// **'Sources, filters, favourites and settings from your phone'**
  String get receiveHint;

  /// No description provided for @sendTitle.
  ///
  /// In en, this message translates to:
  /// **'Send to another device'**
  String get sendTitle;

  /// No description provided for @sendHint.
  ///
  /// In en, this message translates to:
  /// **'Your whole setup to a TV or PC, scanning its code'**
  String get sendHint;

  /// No description provided for @receiveIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring sources, filters, favourites, your list and settings here from your phone. Nothing to type with the remote.'**
  String get receiveIntro;

  /// No description provided for @receiveStep1.
  ///
  /// In en, this message translates to:
  /// **'Open Zapline on your phone'**
  String get receiveStep1;

  /// No description provided for @receiveStep2.
  ///
  /// In en, this message translates to:
  /// **'Settings → Send to another device'**
  String get receiveStep2;

  /// No description provided for @receiveStep3.
  ///
  /// In en, this message translates to:
  /// **'Scan this code'**
  String get receiveStep3;

  /// No description provided for @scanWithZapline.
  ///
  /// In en, this message translates to:
  /// **'Scan with Zapline'**
  String get scanWithZapline;

  /// No description provided for @sameWifi.
  ///
  /// In en, this message translates to:
  /// **'Both on the same Wi-Fi network.'**
  String get sameWifi;

  /// No description provided for @receivedTitle.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get receivedTitle;

  /// No description provided for @downloadingChannels.
  ///
  /// In en, this message translates to:
  /// **'Downloading channels and guide…'**
  String get downloadingChannels;

  /// No description provided for @startWatching.
  ///
  /// In en, this message translates to:
  /// **'Start watching'**
  String get startWatching;

  /// No description provided for @deviceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the TV. Check the phone and the TV are on the same home network and no VPN is on on the phone, then try again.'**
  String get deviceNotFound;

  /// No description provided for @notAZaplineCode.
  ///
  /// In en, this message translates to:
  /// **'That isn\'t a Zapline code.'**
  String get notAZaplineCode;

  /// No description provided for @typeCode.
  ///
  /// In en, this message translates to:
  /// **'Type the code'**
  String get typeCode;

  /// No description provided for @deviceAddress.
  ///
  /// In en, this message translates to:
  /// **'Address shown on the TV'**
  String get deviceAddress;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Sending didn\'t work. Try again.'**
  String get sendFailed;

  /// No description provided for @sendTo.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}'**
  String sendTo(String name);

  /// No description provided for @scanTheCode.
  ///
  /// In en, this message translates to:
  /// **'Scan the code on the TV or PC'**
  String get scanTheCode;

  /// No description provided for @scanTheCodeHint.
  ///
  /// In en, this message translates to:
  /// **'On the TV or PC open Zapline → Receive from another device. Same Wi-Fi network.'**
  String get scanTheCodeHint;

  /// No description provided for @connectedTo.
  ///
  /// In en, this message translates to:
  /// **'Connected. Data stays inside your home network.'**
  String get connectedTo;

  /// No description provided for @sendSources.
  ///
  /// In en, this message translates to:
  /// **'Sources and passwords'**
  String get sendSources;

  /// No description provided for @sourcesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 list} other{{count} lists}}'**
  String sourcesCount(int count);

  /// No description provided for @sendFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters, groups and hidden channels'**
  String get sendFilters;

  /// No description provided for @sendFiltersHint.
  ///
  /// In en, this message translates to:
  /// **'What each list shows'**
  String get sendFiltersHint;

  /// No description provided for @sendFavouritesHint.
  ///
  /// In en, this message translates to:
  /// **'Your favourite channels'**
  String get sendFavouritesHint;

  /// No description provided for @sendGuideHint.
  ///
  /// In en, this message translates to:
  /// **'Added guides and channels matched by hand'**
  String get sendGuideHint;

  /// No description provided for @sendWatching.
  ///
  /// In en, this message translates to:
  /// **'My list and started titles'**
  String get sendWatching;

  /// No description provided for @sendWatchingHint.
  ///
  /// In en, this message translates to:
  /// **'Resume where you left off'**
  String get sendWatchingHint;

  /// No description provided for @sendSettings.
  ///
  /// In en, this message translates to:
  /// **'App settings'**
  String get sendSettings;

  /// No description provided for @sendSettingsHint.
  ///
  /// In en, this message translates to:
  /// **'Language, quality, channel numbers…'**
  String get sendSettingsHint;

  /// No description provided for @sendPinHint.
  ///
  /// In en, this message translates to:
  /// **'Off: you can choose another one there'**
  String get sendPinHint;

  /// No description provided for @sendReplaces.
  ///
  /// In en, this message translates to:
  /// **'What is already there gets replaced.'**
  String get sendReplaces;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @sentTitle.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get sentTitle;

  /// No description provided for @sentHint.
  ///
  /// In en, this message translates to:
  /// **'{name} is downloading the channels now.'**
  String sentHint(String name);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @castButton.
  ///
  /// In en, this message translates to:
  /// **'Send to TV'**
  String get castButton;

  /// No description provided for @castTo.
  ///
  /// In en, this message translates to:
  /// **'Send {title} to…'**
  String castTo(String title);

  /// No description provided for @castSearching.
  ///
  /// In en, this message translates to:
  /// **'Looking for Zapline on your network…'**
  String get castSearching;

  /// No description provided for @castNoneFound.
  ///
  /// In en, this message translates to:
  /// **'No Zapline found. Open Zapline on the TV or PC, on the same Wi-Fi network.'**
  String get castNoneFound;

  /// No description provided for @castZaplineDevice.
  ///
  /// In en, this message translates to:
  /// **'Zapline'**
  String get castZaplineDevice;

  /// No description provided for @castOneStream.
  ///
  /// In en, this message translates to:
  /// **'This phone stops playing and becomes the remote: still one stream.'**
  String get castOneStream;

  /// No description provided for @castNoList.
  ///
  /// In en, this message translates to:
  /// **'{device} doesn\'t have this list. Send it there from Settings → Send to another device.'**
  String castNoList(String device);

  /// No description provided for @castUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach {device}.'**
  String castUnreachable(String device);

  /// No description provided for @castFailed.
  ///
  /// In en, this message translates to:
  /// **'{device} couldn\'t play it.'**
  String castFailed(String device);

  /// No description provided for @castOnAir.
  ///
  /// In en, this message translates to:
  /// **'On air on {device}'**
  String castOnAir(String device);

  /// No description provided for @castLost.
  ///
  /// In en, this message translates to:
  /// **'Lost contact with the TV'**
  String get castLost;

  /// No description provided for @castStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get castStopped;

  /// No description provided for @castWatchHere.
  ///
  /// In en, this message translates to:
  /// **'Watch here'**
  String get castWatchHere;

  /// No description provided for @castStop.
  ///
  /// In en, this message translates to:
  /// **'Stop on the TV'**
  String get castStop;

  /// No description provided for @pinWait.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong PINs. Try again in {seconds} s.'**
  String pinWait(int seconds);

  /// No description provided for @castLocked.
  ///
  /// In en, this message translates to:
  /// **'That channel is locked with the PIN on {device}.'**
  String castLocked(String device);

  /// No description provided for @castCodeExpired.
  ///
  /// In en, this message translates to:
  /// **'The code expired. Close and try again.'**
  String get castCodeExpired;

  /// No description provided for @castPairTitle.
  ///
  /// In en, this message translates to:
  /// **'Pair with {device}'**
  String castPairTitle(String device);

  /// No description provided for @castPairHint.
  ///
  /// In en, this message translates to:
  /// **'Type the code now showing on {device}. You only do this once.'**
  String castPairHint(String device);

  /// No description provided for @castPairing.
  ///
  /// In en, this message translates to:
  /// **'Pair a phone'**
  String get castPairing;

  /// No description provided for @castPairingAsk.
  ///
  /// In en, this message translates to:
  /// **'{phone} wants to send what it plays to this screen. Type this code on it:'**
  String castPairingAsk(String phone);

  /// No description provided for @castAPhone.
  ///
  /// In en, this message translates to:
  /// **'A phone'**
  String get castAPhone;

  /// No description provided for @castPairedPhones.
  ///
  /// In en, this message translates to:
  /// **'Paired phones'**
  String get castPairedPhones;

  /// No description provided for @castPairedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 phone can send to this screen} other{{count} phones can send to this screen}}'**
  String castPairedCount(int count);

  /// No description provided for @castUnpairAll.
  ///
  /// In en, this message translates to:
  /// **'Unpair all'**
  String get castUnpairAll;

  /// No description provided for @castUnpaired.
  ///
  /// In en, this message translates to:
  /// **'Phones unpaired'**
  String get castUnpaired;

  /// No description provided for @noKeystoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Passwords kept in Zapline only'**
  String get noKeystoreTitle;

  /// No description provided for @noKeystoreHint.
  ///
  /// In en, this message translates to:
  /// **'This system has no working keystore, so source passwords are saved in Zapline\'s own data on this device.'**
  String get noKeystoreHint;

  /// No description provided for @updateGroup.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateGroup;

  /// No description provided for @updateAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version {version}'**
  String updateAvailable(String version);

  /// No description provided for @updateHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to download and install it'**
  String get updateHint;

  /// No description provided for @updateHintDesktop.
  ///
  /// In en, this message translates to:
  /// **'Opens the download page'**
  String get updateHintDesktop;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateNow;

  /// No description provided for @updateDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading… {percent}%'**
  String updateDownloading(int percent);

  /// No description provided for @updateAllowInstall.
  ///
  /// In en, this message translates to:
  /// **'Allow Zapline to install apps, then come back and tap Update'**
  String get updateAllowInstall;

  /// No description provided for @updateFailed.
  ///
  /// In en, this message translates to:
  /// **'Update failed: {error}'**
  String updateFailed(String error);

  /// No description provided for @updateAnnounce.
  ///
  /// In en, this message translates to:
  /// **'A new version of Zapline is out'**
  String get updateAnnounce;

  /// No description provided for @checkUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get checkUpdates;

  /// No description provided for @checkUpdatesHint.
  ///
  /// In en, this message translates to:
  /// **'When it opens and now and then, asks GitHub for the latest version. Nothing about you is sent'**
  String get checkUpdatesHint;

  /// No description provided for @checkUpdatesNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get checkUpdatesNow;

  /// No description provided for @checkingUpdates.
  ///
  /// In en, this message translates to:
  /// **'Checking…'**
  String get checkingUpdates;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'Zapline is up to date'**
  String get upToDate;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not reach GitHub, try again later'**
  String get updateCheckFailed;

  /// No description provided for @sendTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The TV didn\'t answer in time. Keep it on “Receive” and try again: what already arrived stays.'**
  String get sendTimedOut;

  /// No description provided for @loadingYourList.
  ///
  /// In en, this message translates to:
  /// **'Loading your playlist'**
  String get loadingYourList;

  /// No description provided for @loadingYourListHint.
  ///
  /// In en, this message translates to:
  /// **'Channels, films and the guide arrive shortly: you can wait here.'**
  String get loadingYourListHint;

  /// No description provided for @updatingList.
  ///
  /// In en, this message translates to:
  /// **'Updating the playlist…'**
  String get updatingList;

  /// No description provided for @setupReceived.
  ///
  /// In en, this message translates to:
  /// **'Setup received from the phone'**
  String get setupReceived;

  /// No description provided for @searchMovies.
  ///
  /// In en, this message translates to:
  /// **'Search films'**
  String get searchMovies;

  /// No description provided for @searchShows.
  ///
  /// In en, this message translates to:
  /// **'Search series'**
  String get searchShows;
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
