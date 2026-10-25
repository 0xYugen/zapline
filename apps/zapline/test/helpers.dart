import 'package:zapline/src/app_state.dart';
import 'package:zapline/src/secret_store.dart';
import 'package:zapline_core/zapline_core.dart';
import 'package:zapline_data/zapline_data.dart';

/// An [AppState] over an in-memory database whose "sync" writes [count]
/// fake channels and a guide instead of touching the network.
/// Every channel whose number is in [unmatched] gets a name and no guide id
/// that the automatic matcher cannot link.
AppState fakeState({
  int count = 20,
  Set<int> unmatched = const {},
  ZaplineDatabase? database,
  SecretStore? secrets,
  ChannelGuideFetcher? guideFetcher,
  bool vod = false,
  List<String>? names,
  List<String>? groups,
}) {
  final db = database ?? ZaplineDatabase.inMemory();
  // An established user: the one-time TV hint has been seen.
  db.setSetting('holdOkHintShown', '1');
  return AppState(
    db,
    secrets: secrets,
    guideFetcher: guideFetcher,
    syncRunner: (source, onProgress) async {
      final channels = [
        for (var i = 1; i <= count; i++)
          Channel(
            sourceId: source.id,
            id: '$i',
            name: names != null && i <= names.length
                ? names[i - 1]
                : unmatched.contains(i)
                ? 'Channel $i Extra'
                : 'Channel $i',
            number: i,
            groupTitle: groups != null
                ? groups[(i - 1) % groups.length]
                : i.isEven
                ? 'Even'
                : 'Odd',
            epgChannelId: unmatched.contains(i) ? null : 'g$i',
            streamUrl: Uri.parse('http://x.example/live/u/p/$i.ts'),
            catchup: const CatchupInfo(mode: CatchupMode.xtream, days: 2),
          ),
      ];
      db.replaceChannels(source.id, channels);
      if (vod) seedVod(db, source.id);
      final now = DateTime.now().toUtc();
      Stream<XmltvItem> guide() async* {
        for (var i = 1; i <= count; i++) {
          yield XmltvChannel(id: 'g$i', displayNames: ['Channel $i']);
          for (var h = -2; h < 6; h++) {
            final start = DateTime.utc(
              now.year,
              now.month,
              now.day,
              now.hour,
            ).add(Duration(hours: h));
            yield XmltvProgramme(
              Programme(
                channelId: 'g$i',
                start: start,
                stop: start.add(const Duration(hours: 1)),
                title: 'Show $i.$h',
              ),
            );
          }
        }
      }

      final g = await db.importGuide(guide());
      final cov = db.rebuildGuideLinks();
      db.markSynced(source.id, now);
      return SyncResult(channels: count, guide: g, coverage: cov);
    },
  );
}

/// A small film and series catalogue, as a playlist would give.
void seedVod(ZaplineDatabase db, String sourceId) {
  final added = DateTime.utc(2026, 1, 1);
  db.replaceMovies(sourceId, [
    for (var i = 1; i <= 36; i++)
      Movie(
        sourceId: sourceId,
        id: '$i',
        name: 'IT - Film $i (${2000 + i % 25})',
        category: switch (i % 3) {
          0 => 'IT | Azione',
          1 => 'IT | Commedia',
          _ => 'EN | Drama',
        },
        rating: 5 + (i % 5),
        addedAt: added.add(Duration(days: i)),
        streamUrl: Uri.parse('http://x.example/movie/u/p/$i.mp4'),
      ),
  ]);
  db.replaceShows(
    sourceId,
    [
      for (var i = 1; i <= 12; i++)
        Show(
          sourceId: sourceId,
          id: 'serie $i',
          name: 'Serie $i',
          category: i.isEven ? 'IT | Serie TV' : 'EN | Series',
          plot:
              'A plot for series $i that is long enough to wrap over a '
              'couple of lines on a phone.',
          releaseDate: '2019-05-01',
          rating: 7.5,
        ),
    ],
    playlistEpisodes: [
      for (var i = 1; i <= 12; i++)
        for (var season = 1; season <= 2; season++)
          for (var e = 1; e <= 6; e++)
            (
              'serie $i',
              Episode(
                id: '${season}x$e',
                season: season,
                number: e,
                title: 'Serie $i S0${season}E0$e Episode title $e',
                streamUrl: Uri.parse(
                  'http://x.example/series/u/p/$i$season$e.mp4',
                ),
              ),
            ),
    ],
  );
}
