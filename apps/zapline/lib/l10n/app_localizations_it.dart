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
}
