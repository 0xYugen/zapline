// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get allChannels => 'Tutti i canali';

  @override
  String get favourites => 'Preferiti';

  @override
  String get recent => 'Recenti';

  @override
  String get noGroup => 'Senza gruppo';

  @override
  String get groups => 'Gruppi';

  @override
  String get allGroups => 'Tutti i gruppi';

  @override
  String get findGroup => 'Cerca un gruppo';

  @override
  String get noChannelsInGroup => 'Nessun canale in questo gruppo.';

  @override
  String get groupLocked => 'Questo gruppo è bloccato';

  @override
  String get unlockWithPin => 'Sblocca con il PIN';

  @override
  String get pressOkForPin => 'Premi OK per inserire il PIN.';

  @override
  String get enterPin => 'Inserisci il PIN';

  @override
  String get wrongPin => 'PIN errato';

  @override
  String get pinDelete => 'Cancella';

  @override
  String get cancel => 'Annulla';

  @override
  String get tvGuide => 'Guida TV';

  @override
  String get search => 'Cerca';

  @override
  String get sources => 'Sorgenti';

  @override
  String get settings => 'Impostazioni';

  @override
  String get channels => 'Canali';

  @override
  String get guide => 'Guida';

  @override
  String get liveTv => 'TV in diretta';

  @override
  String get holdOkHint =>
      'Tieni premuto OK su un canale per preferiti, nascondere e guida';

  @override
  String get noGuideInfo => 'Nessuna informazione';

  @override
  String get noGuide => 'Nessuna guida';

  @override
  String get noGuideAtTime => 'Nessuna guida per quest\'ora';

  @override
  String get earlier => 'Prima';

  @override
  String get later => 'Dopo';

  @override
  String get today => 'Oggi';

  @override
  String get yesterday => 'Ieri';

  @override
  String get tomorrow => 'Domani';

  @override
  String get now => 'Adesso';

  @override
  String tonightAt(String time) {
    return 'Stasera $time';
  }

  @override
  String get pickTime => 'Scegli un orario';

  @override
  String atTime(String time) {
    return 'Alle $time';
  }

  @override
  String thenAt(String time, String title) {
    return 'poi $time $title';
  }

  @override
  String get onNow => 'IN ONDA';

  @override
  String get replay => 'REPLAY';

  @override
  String get watchLive => 'Guarda in diretta';

  @override
  String get noGuideForChannel =>
      'Nessuna guida per questo canale.\nPuoi collegarne una da Impostazioni → Sorgenti → Correggi la guida.';

  @override
  String get inTheTvGuide => 'Nella guida TV';

  @override
  String get channelOrProgramme => 'Canale o programma';

  @override
  String get nothingFound => 'Nessun risultato.';

  @override
  String get fixTvGuide => 'Correggi la guida';

  @override
  String get fixDone => 'Fatto. Premi Indietro per tornare.';

  @override
  String get fixAllMatched =>
      'Tutti i canali di questa sorgente hanno la guida.';

  @override
  String fixUnmatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali non hanno la guida.',
      one: '1 canale non ha la guida.',
    );
    return '$_temp0 Scegline uno, poi il canale della guida corrispondente.';
  }

  @override
  String get pickChannelAbove => 'Scegli un canale qui sopra.';

  @override
  String suggestionsFor(String name) {
    return 'Suggerimenti per $name';
  }

  @override
  String get guideChannels => 'Canali della guida';

  @override
  String get searchTheGuide => 'Cerca nella guida';

  @override
  String get nothingFoundTryAnother => 'Nessun risultato. Prova un altro nome.';

  @override
  String get backupTitle => 'Backup e ripristino';

  @override
  String get backupIntro =>
      'Salva sorgenti, preferiti e correzioni della guida in un file, o riportali su un nuovo dispositivo. Apri la pagina indicata qui in un browser sulla stessa rete.';

  @override
  String get backupPrivate =>
      'Il file di backup contiene le password delle sorgenti: tienilo privato.';

  @override
  String get backupOpenOnComputer =>
      'Su un computer nella stessa rete Wi-Fi, apri';

  @override
  String get backupOpenHere => 'Su questo computer, apri';

  @override
  String backupCode(String pin) {
    return 'Codice $pin';
  }

  @override
  String get noLocalNetwork =>
      'Questo dispositivo non è collegato a una rete locale.';

  @override
  String restoring(String progress) {
    return 'Ripristino… $progress';
  }

  @override
  String get pressBackWhenDone => 'Premi Indietro quando hai finito.';

  @override
  String get useYourPhone => 'Usa il telefono';

  @override
  String get backupScan => 'Inquadra per scaricare un backup o ripristinarlo.';

  @override
  String get qrLabel => 'Codice QR per aggiungere una sorgente dal telefono';

  @override
  String get orOpenOnPhone => 'Oppure apri sul telefono';

  @override
  String get code => 'Codice';

  @override
  String get addToFavourites => 'Aggiungi ai preferiti';

  @override
  String get removeFromFavourites => 'Togli dai preferiti';

  @override
  String get hideChannel => 'Nascondi questo canale';

  @override
  String get hiddenHint =>
      'Puoi mostrarlo di nuovo dai canali nascosti della sorgente';

  @override
  String get fixItsGuide => 'Correggi la sua guida';

  @override
  String get freeEpgByCountry => 'EPG gratuito per paese';

  @override
  String get freeEpgNote =>
      'Palinsesti da fonti pubbliche (iptv-epg.org, epgshare01, open-epg.com), gratuiti per uso legale. I canali vengono abbinati per nome.';

  @override
  String get findCountry => 'Cerca un paese';

  @override
  String minutesLeft(int minutes) {
    return 'mancano $minutes min';
  }

  @override
  String hoursMinutesLeft(int hours, int minutes) {
    return 'mancano $hours h $minutes min';
  }

  @override
  String get language => 'Lingua';

  @override
  String get languageDevice => 'Come il dispositivo';

  @override
  String get watch => 'Guarda';

  @override
  String get fromTheStart => 'Dall\'inizio';

  @override
  String get replayAction => 'Rivedi';

  @override
  String get remindMe => 'Ricordamelo';

  @override
  String get reminderSet => 'Promemoria attivo';

  @override
  String get watchChannel => 'Guarda il canale';

  @override
  String nextAt(String time, String title) {
    return 'Dopo: $time $title';
  }

  @override
  String get continueWatching => 'Continua a guardare';

  @override
  String get favouritesEmpty =>
      'Ancora nessun preferito.\nTieni premuto un canale e scegli “Aggiungi ai preferiti”.';

  @override
  String reminderNow(String title, String channel) {
    return '$title sta per iniziare su $channel';
  }

  @override
  String get searchTooltip => 'Cerca canali e programmi';

  @override
  String get lessThanAMinute => 'Sta finendo';

  @override
  String get back => 'Indietro';

  @override
  String get previousChannel => 'Canale precedente';

  @override
  String get nextChannel => 'Canale successivo';

  @override
  String get backToLive => 'Torna alla diretta';

  @override
  String get watchFromStart => 'Guarda dall\'inizio';

  @override
  String get startShort => 'INIZIO';

  @override
  String get liveShort => 'DIRETTA';

  @override
  String get liveBadge => 'LIVE';

  @override
  String get catchUpBadge => 'REPLAY';

  @override
  String get pictureSize => 'Immagine: adatta, zoom, estendi';

  @override
  String get channelList => 'Canali';

  @override
  String get programmeInfo => 'Info programma';

  @override
  String get audioAndSubtitles => 'Audio e sottotitoli';

  @override
  String get audio => 'Audio';

  @override
  String get subtitles => 'Sottotitoli';

  @override
  String get subtitlesOff => 'Disattivati';

  @override
  String trackNumber(int n) {
    return 'Traccia $n';
  }

  @override
  String get noOtherTracks => 'Questo canale ha una sola traccia audio.';

  @override
  String get swipeHint => 'Scorri su o giù per cambiare canale';

  @override
  String get noArchive => 'Nessun archivio per questo programma';

  @override
  String get channelUnavailable => 'Questo canale ora non è disponibile';

  @override
  String get archiveUnavailable =>
      'Questo programma non è disponibile nell\'archivio';

  @override
  String get tryAnotherChannelKeys =>
      'Premi Su o Giù per provare un altro canale.';

  @override
  String get tryAnotherChannelTouch =>
      'Scorri su o giù per provare un altro canale.';

  @override
  String get pressRightForLive => 'Premi Destra per tornare alla diretta.';

  @override
  String catchUpLine(String title) {
    return 'Replay: $title';
  }

  @override
  String nowLine(String title) {
    return 'Ora: $title';
  }

  @override
  String get prevChannelKey => 'Canale precedente (Pag Su)';

  @override
  String get nextChannelKey => 'Canale successivo (Pag Giù)';

  @override
  String get channelListKey => 'Lista canali (Invio)';

  @override
  String get tuning => 'sintonizzazione…';

  @override
  String zapTime(int ms) {
    return 'zap $ms ms';
  }

  @override
  String get refreshing => 'Aggiornamento…';

  @override
  String get refreshed => 'Aggiornato.';

  @override
  String refreshFailed(String error) {
    return 'Aggiornamento non riuscito: $error';
  }

  @override
  String get enterFullLink => 'Inserisci un link completo, che inizi con http.';

  @override
  String get guideAdded => 'Guida aggiunta. Aggiorna per caricarla.';

  @override
  String loadingFreeEpg(String country) {
    return 'Caricamento dell\'EPG gratuito per $country…';
  }

  @override
  String freeEpgAdded(String country, int matched, int total) {
    return 'EPG $country aggiunto: guida TV per $matched canali su $total.';
  }

  @override
  String get shiftSaved => 'Spostamento salvato. Aggiorna per applicarlo.';

  @override
  String get noGroupChannels => 'Canali senza gruppo';

  @override
  String get setPinFirst =>
      'Imposta un PIN nelle Impostazioni prima di bloccare i gruppi.';

  @override
  String get unlockGroup => 'Sblocca (senza PIN)';

  @override
  String get lockWithPin => 'Blocca con il PIN';

  @override
  String get followFilterAgain => 'Torna a seguire il filtro';

  @override
  String get sectionGuide => 'Guida TV (EPG)';

  @override
  String get sectionGroups => 'Gruppi e filtri';

  @override
  String get sectionHidden => 'Canali nascosti';

  @override
  String get sectionName => 'Nome e accesso';

  @override
  String get name => 'Nome';

  @override
  String get nameSaved => 'Nome salvato.';

  @override
  String get save => 'Salva';

  @override
  String get server => 'Server';

  @override
  String get username => 'Nome utente';

  @override
  String get tvGuidesEpg => 'Guide TV (EPG)';

  @override
  String get epgIntro =>
      'L\'EPG della sorgente si carica da solo. Qui puoi aggiungere altri link EPG (XMLTV); per ogni canale vince il primo che lo contiene.';

  @override
  String get addFreeEpgByCountry => 'Aggiungi un EPG gratuito per paese';

  @override
  String freeEpgEntry(String country, String host) {
    return 'EPG gratuito · $country ($host)';
  }

  @override
  String get guideRemoved => 'Guida rimossa.';

  @override
  String get remove => 'Rimuovi';

  @override
  String get addEpgLink => 'Aggiungi un link EPG (XMLTV, .xml o .xml.gz)';

  @override
  String get add => 'Aggiungi';

  @override
  String get guideTimeShift => 'Spostamento orario della guida';

  @override
  String get guideTimeShiftHint => 'Per le guide con gli orari sbagliati.';

  @override
  String get refreshNow => 'Aggiorna ora';

  @override
  String get showTheseGroups => 'Mostra questi gruppi';

  @override
  String get filterHelp =>
      'Parole separate da virgole. IT trova \"IT | Sport\" ma non \"Hits\"; ital* trova Italia e Italy; IT| trova esattamente quel testo. Nascondere vince sempre.';

  @override
  String get presetItalian => 'Solo italiani';

  @override
  String get presetAdult => 'Nascondi adulti';

  @override
  String get presetVod => 'Nascondi film e serie';

  @override
  String get clear => 'Svuota';

  @override
  String get showOnlyGroupsWith => 'Mostra solo i gruppi con (vuoto = tutti)';

  @override
  String get hideGroupsWith => 'Nascondi i gruppi con';

  @override
  String filterPreview(int groups, int all, int channels) {
    return 'Mostra $groups gruppi su $all · $channels canali';
  }

  @override
  String get filterApplied => 'Filtro applicato.';

  @override
  String get applyFilter => 'Applica il filtro';

  @override
  String get applied => 'Applicato';

  @override
  String get groupsHelp =>
      'Tocca per mostrare o nascondere un gruppo. Tieni premuto per bloccarlo con il PIN o farlo tornare a seguire il filtro.';

  @override
  String groupState(int count, String state, String by) {
    String _temp0 = intl.Intl.selectLogic(state, {
      'hidden': 'nascosto',
      'other': 'visibile',
    });
    String _temp1 = intl.Intl.selectLogic(by, {
      'filter': ' dal filtro',
      'other': '',
    });
    return '$count · $_temp0$_temp1';
  }

  @override
  String get noHiddenChannels =>
      'Nessun canale nascosto. Tieni premuto un canale e scegli “Nascondi questo canale”.';

  @override
  String get showAgain => 'Mostra di nuovo';

  @override
  String refreshResult(int channels, int programmes) {
    return '$channels canali, $programmes programmi in guida';
  }

  @override
  String refreshGuideFailed(String errors) {
    return 'Canali aggiornati, guida non riuscita ($errors)';
  }

  @override
  String removeSourceTitle(String name) {
    return 'Rimuovere $name?';
  }

  @override
  String get removeSourceMessage =>
      'Spariscono anche i suoi canali, preferiti e abbinamenti della guida. Potrai riaggiungerla in seguito.';

  @override
  String get removeSource => 'Rimuovi questa sorgente';

  @override
  String channelsWithoutGuide(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali non hanno ancora la guida TV.',
      one: '1 canale non ha ancora la guida TV.',
    );
    return '$_temp0';
  }

  @override
  String addFreeEpgFor(String country) {
    return 'Aggiungi l\'EPG gratuito per $country';
  }

  @override
  String get addFreeEpg => 'Aggiungi un EPG gratuito';

  @override
  String get matchThem => 'Abbinali';

  @override
  String get guideFromSource => 'Dalla sorgente';

  @override
  String freeEpgShort(String countries) {
    return 'EPG gratuito $countries';
  }

  @override
  String extraGuides(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count guide in più',
      one: '1 guida in più',
    );
    return '$_temp0';
  }

  @override
  String shiftedBy(String value) {
    return 'spostata $value';
  }

  @override
  String get filterOn => 'Filtro attivo';

  @override
  String groupsShown(int shown, int all) {
    return '$shown gruppi visibili su $all';
  }

  @override
  String hiddenCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nascosti',
      one: '1 nascosto',
      zero: 'Nessuno',
    );
    return '$_temp0';
  }

  @override
  String syncingProgress(String progress) {
    return 'Aggiornamento… $progress';
  }

  @override
  String epgFailed(String errors) {
    return 'Impossibile caricare l\'EPG: $errors';
  }

  @override
  String get epgEmptyPerChannel =>
      'La sorgente ha mandato un EPG vuoto; cosa c\'è in onda viene chiesto canale per canale.';

  @override
  String get epgEmpty =>
      'La sorgente ha mandato un EPG vuoto. Aggiungi un EPG gratuito o un link.';

  @override
  String updatedAt(String day, String time) {
    return 'Aggiornata $day alle $time';
  }

  @override
  String get neverSynced => 'Mai aggiornata';

  @override
  String channelCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count canali',
      one: '1 canale',
    );
    return '$_temp0';
  }

  @override
  String guideFor(int count) {
    return 'Guida TV per $count';
  }

  @override
  String guidePercent(int percent) {
    return 'guida $percent%';
  }

  @override
  String get addSource => 'Aggiungi una sorgente';

  @override
  String get watching => 'Visione';

  @override
  String get openLastChannel => 'Apri l\'ultimo canale all\'avvio';

  @override
  String get openLastChannelHint => 'Come accendere la TV.';

  @override
  String get pictureSizeSetting => 'Formato immagine';

  @override
  String get fitFit => 'Adatta';

  @override
  String get fitZoom => 'Zoom';

  @override
  String get fitStretch => 'Estendi';

  @override
  String get channelNumbers => 'Numeri dei canali';

  @override
  String get numbersProvider => 'Del provider';

  @override
  String get numbersSequential => '1, 2, 3…';

  @override
  String get clock24h => 'Orologio a 24 ore';

  @override
  String get daysToKeep => 'Giorni di guida da tenere';

  @override
  String get daysToKeepHint =>
      'Meno giorni aggiornano più in fretta sui dispositivi piccoli.';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count giorni',
      one: '1 giorno',
    );
    return '$_temp0';
  }

  @override
  String get updateAutomatically => 'Aggiorna le sorgenti in automatico';

  @override
  String get refreshNever => 'Mai';

  @override
  String everyHours(int hours) {
    return 'Ogni $hours h';
  }

  @override
  String get privacyAndSafety => 'Privacy e sicurezza';

  @override
  String get parentalPin => 'PIN parentale';

  @override
  String get parentalPinHint => 'I gruppi bloccati chiedono il PIN.';

  @override
  String get on => 'Attivo';

  @override
  String get off => 'Disattivo';

  @override
  String get about => 'Informazioni';

  @override
  String get aboutLine =>
      'Libero e open source · Nessun canale incluso · Licenze';

  @override
  String get choosePin => 'Scegli un PIN di 4 cifre';

  @override
  String get enterItAgain => 'Inseriscilo di nuovo';

  @override
  String get pinsDiffer => 'I due PIN sono diversi. Nessuna modifica.';

  @override
  String get pinSaved =>
      'PIN salvato. Blocca i gruppi da Gruppi e filtri della sorgente.';

  @override
  String get enterCurrentPin => 'Inserisci il PIN attuale';

  @override
  String get pinRemoved => 'PIN rimosso e tutti i gruppi sbloccati.';

  @override
  String get changePin => 'Cambia PIN';

  @override
  String get removePin => 'Rimuovi PIN';

  @override
  String get lockNow => 'Blocca ora';

  @override
  String get lockedAgain => 'Gruppi bloccati di nuovo nascosti.';

  @override
  String get tagline =>
      'I tuoi canali, la tua guida TV. Gratis, senza account, senza pubblicità.';

  @override
  String get howDoYouGetChannels => 'Come ricevi i tuoi canali?';

  @override
  String get xtreamChoice => 'Accesso al server (Xtream)';

  @override
  String get xtreamChoiceHint => 'Indirizzo del server, nome utente e password';

  @override
  String get m3uChoice => 'Link della playlist (M3U)';

  @override
  String get m3uChoiceHint => 'Un link che finisce in .m3u o .m3u8';

  @override
  String get restoreChoice => 'Ripristina un backup';

  @override
  String get restoreChoiceHint =>
      'Porta sorgenti e preferiti da un altro dispositivo';

  @override
  String get noChannelsIncluded =>
      'Zapline non include canali né playlist. Riproduce solo le sorgenti che aggiungi.';

  @override
  String get errorDuplicate => 'Questa sorgente è già stata aggiunta.';

  @override
  String get errorUnreachable =>
      'Impossibile raggiungere il server. Controlla l\'indirizzo e la connessione a internet.';

  @override
  String get errorLogin =>
      'Il server ha rifiutato l\'accesso. Controlla nome utente e password.';

  @override
  String get errorNotFound =>
      'Nessun contenuto a quell\'indirizzo. Controlla il link.';

  @override
  String errorGeneric(String error) {
    return 'Connessione non riuscita: $error';
  }

  @override
  String get pairingHint =>
      'Inquadra il codice e incolla lì i tuoi dati. Niente da scrivere sulla TV.';

  @override
  String get paste => 'Incolla';

  @override
  String get addFirstSource => 'Aggiungi la tua prima sorgente';

  @override
  String get xtreamFormHint =>
      'Incolla il link che ti ha mandato il provider: se contiene nome utente e password, li compiliamo noi.';

  @override
  String get m3uFormHint =>
      'Incolla il link della playlist. Se il provider ti ha dato anche un link della guida TV (EPG), aggiungilo sotto.';

  @override
  String get addSourceHint =>
      'Incolla il link di una playlist o l\'indirizzo del server. I link Xtream vengono riconosciuti da soli e la guida TV si imposta in automatico.';

  @override
  String get serverAddress => 'Indirizzo del server';

  @override
  String get playlistLink => 'Link della playlist';

  @override
  String get urlOrServer => 'Link della playlist o indirizzo del server';

  @override
  String xtreamDetected(String user, String host) {
    return 'Accesso Xtream riconosciuto: $user @ $host';
  }

  @override
  String get epgLinkOptional => 'Link della guida TV (EPG), facoltativo';

  @override
  String get storedOnDevice =>
      'Salvati solo su questo dispositivo, nell\'archivio sicuro del sistema.';

  @override
  String get connect => 'Collegati';

  @override
  String get restoreFromBackup => 'Ripristina da un backup';

  @override
  String get usernameXtreamOnly => 'Nome utente (solo Xtream)';

  @override
  String get password => 'Password';

  @override
  String get passwordXtreamOnly => 'Password (solo Xtream)';

  @override
  String get hidePassword => 'Nascondi password';

  @override
  String get showPassword => 'Mostra password';

  @override
  String get connecting => 'Connessione…';

  @override
  String get stepLogin => 'Accesso';

  @override
  String get stepChannels => 'Canali';

  @override
  String stepChannelsCount(int count) {
    return '$count canali';
  }

  @override
  String get stepGuide => 'Guida TV';

  @override
  String stepGuideCount(int count) {
    return 'Guida $count';
  }

  @override
  String get stepMatching => 'Abbinamento';

  @override
  String get epgOfferTitle => 'Vuoi una guida TV più completa?';

  @override
  String epgOfferMessage(int count, String country) {
    return '$count canali di questa sorgente non hanno la guida TV. Un EPG pubblico gratuito per $country può coprirne la maggior parte.';
  }

  @override
  String get notNow => 'Non ora';
}
