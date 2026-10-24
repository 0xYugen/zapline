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
}) {
  final db = database ?? ZaplineDatabase.inMemory();
  return AppState(
    db,
    secrets: secrets,
    syncRunner: (source, onProgress) async {
      final channels = [
        for (var i = 1; i <= count; i++)
          Channel(
            sourceId: source.id,
            id: '$i',
            name: unmatched.contains(i) ? 'Channel $i Extra' : 'Channel $i',
            number: i,
            groupTitle: i.isEven ? 'Even' : 'Odd',
            epgChannelId: unmatched.contains(i) ? null : 'g$i',
            streamUrl: Uri.parse('http://x.example/live/u/p/$i.ts'),
            catchup: const CatchupInfo(mode: CatchupMode.xtream, days: 2),
          ),
      ];
      db.replaceChannels(source.id, channels);
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
