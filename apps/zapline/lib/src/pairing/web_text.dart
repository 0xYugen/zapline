import 'dart:convert';
import 'dart:io';

/// Words of the pages and replies the TV serves to a phone or PC browser,
/// in the language that browser asks for: Italian or English for now, like
/// the app. Kept here rather than in the app's translations because these
/// servers answer outside any screen.
class WebText {
  const WebText._({
    required this.lang,
    required this.codeOnTv,
    required this.wrongCode,
    required this.tooManyCodes,
    required this.enterAddress,
    required this.tvNoAnswer,
    required this.addTitle,
    required this.addHeading,
    required this.addLead,
    required this.linkOrServer,
    required this.xtreamHint,
    required this.username,
    required this.password,
    required this.extraGuide,
    required this.epgLink,
    required this.sendToTv,
    required this.connecting,
    required this.addTvGone,
    required this.privacy,
    required this.backupTitle,
    required this.downloadHeading,
    required this.downloadLead,
    required this.downloadWarn,
    required this.downloadButton,
    required this.restoreHeading,
    required this.restoreLead,
    required this.restoreButton,
    required this.chooseFile,
    required this.restoring,
    required this.backupTvGone,
  });

  final String lang;
  final String codeOnTv;
  final String wrongCode;
  final String tooManyCodes;
  final String enterAddress;
  final String tvNoAnswer;
  final String addTitle;
  final String addHeading;
  final String addLead;
  final String linkOrServer;
  final String xtreamHint;
  final String username;
  final String password;
  final String extraGuide;
  final String epgLink;
  final String sendToTv;
  final String connecting;
  final String addTvGone;
  final String privacy;
  final String backupTitle;
  final String downloadHeading;
  final String downloadLead;
  final String downloadWarn;
  final String downloadButton;
  final String restoreHeading;
  final String restoreLead;
  final String restoreButton;
  final String chooseFile;
  final String restoring;
  final String backupTvGone;

  static const en = WebText._(
    lang: 'en',
    codeOnTv: 'Code shown on the TV',
    wrongCode: 'Wrong code. Check the 4 digits shown on the TV.',
    tooManyCodes:
        'Too many wrong codes. Reopen the screen on the TV to get a new one.',
    enterAddress: 'Enter an address.',
    tvNoAnswer: 'The TV did not answer.',
    addTitle: 'Add a source',
    addHeading: 'Add a source to your TV',
    addLead:
        'Paste your playlist link, or your server address with username and '
        'password.',
    linkOrServer: 'Playlist link or server address',
    xtreamHint:
        'An Xtream link (get.php?username=…) already contains the login: no '
        'need to fill the fields below.',
    username: 'Username',
    password: 'Password',
    extraGuide: 'Extra TV guide (optional)',
    epgLink: 'EPG link (XMLTV)',
    sendToTv: 'Send to TV',
    connecting: 'Connecting… the TV is loading your channels.',
    addTvGone: 'The TV did not answer. Is "Add a source" still open?',
    privacy:
        'Your details travel only over your home network, straight to the '
        'TV. Zapline includes no channels or playlists.',
    backupTitle: 'Backup and restore',
    downloadHeading: 'Download a backup',
    downloadLead: 'Your sources, favourites and guide fixes in one file.',
    downloadWarn: 'The file contains your source passwords. Keep it private.',
    downloadButton: 'Download backup',
    restoreHeading: 'Restore',
    restoreLead:
        'Pick a Zapline backup file. Sources already on the TV are kept.',
    restoreButton: 'Restore to TV',
    chooseFile: 'Choose a file first.',
    restoring: 'Restoring… the TV is downloading your sources.',
    backupTvGone: 'The TV did not answer. Is the backup screen still open?',
  );

  static const it = WebText._(
    lang: 'it',
    codeOnTv: 'Codice mostrato sulla TV',
    wrongCode: 'Codice sbagliato. Controlla le 4 cifre mostrate sulla TV.',
    tooManyCodes:
        'Troppi codici sbagliati. Riapri la schermata sulla TV per averne uno '
        'nuovo.',
    enterAddress: 'Inserisci un indirizzo.',
    tvNoAnswer: 'La TV non ha risposto.',
    addTitle: 'Aggiungi una sorgente',
    addHeading: 'Aggiungi una sorgente alla TV',
    addLead:
        'Incolla il link della playlist, oppure l’indirizzo del server con '
        'nome utente e password.',
    linkOrServer: 'Link della playlist o indirizzo del server',
    xtreamHint:
        'Un link Xtream (get.php?username=…) contiene già l’accesso: non serve '
        'compilare i campi qui sotto.',
    username: 'Nome utente',
    password: 'Password',
    extraGuide: 'Guida TV aggiuntiva (facoltativa)',
    epgLink: 'Link EPG (XMLTV)',
    sendToTv: 'Invia alla TV',
    connecting: 'Connessione… la TV sta caricando i tuoi canali.',
    addTvGone:
        'La TV non ha risposto. «Aggiungi una sorgente» è ancora aperto?',
    privacy:
        'I tuoi dati viaggiano solo sulla rete di casa, direttamente alla TV. '
        'Zapline non include canali né playlist.',
    backupTitle: 'Backup e ripristino',
    downloadHeading: 'Scarica un backup',
    downloadLead:
        'Le tue sorgenti, i preferiti e le correzioni della guida '
        'in un unico file.',
    downloadWarn:
        'Il file contiene le password delle sorgenti. Tienilo al sicuro.',
    downloadButton: 'Scarica il backup',
    restoreHeading: 'Ripristina',
    restoreLead:
        'Scegli un file di backup di Zapline. Le sorgenti già sulla '
        'TV restano.',
    restoreButton: 'Ripristina sulla TV',
    chooseFile: 'Prima scegli un file.',
    restoring: 'Ripristino… la TV sta scaricando le tue sorgenti.',
    backupTvGone:
        'La TV non ha risposto. La schermata di backup è ancora aperta?',
  );

  /// The language the browser or app prefers, by its Accept-Language.
  static WebText of(HttpRequest req) =>
      forLanguages(req.headers.value(HttpHeaders.acceptLanguageHeader));

  static WebText forLanguages(String? acceptLanguage) {
    for (final part in (acceptLanguage ?? '').split(',')) {
      final code = part.trim().split(RegExp('[-_;]')).first.toLowerCase();
      if (code == 'it') return it;
      if (code == 'en') return en;
    }
    return en;
  }

  /// [s] as a JavaScript string literal.
  static String js(String s) => jsonEncode(s);
}
