import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

/// Free guides list DAZN's event feeds ("DAZN1.it", only "No Game Today")
/// next to the real DAZN 1 schedule under another id: the channel gets the
/// one with programmes.
void main() {
  const events = XmltvChannel(id: 'DAZN1.it', displayNames: ['DAZN 1']);
  const real = XmltvChannel(id: 'DAZN.1.it.it', displayNames: ['DAZN 1']);

  Channel ch(String name, {String? epg}) => Channel(
        sourceId: 's',
        id: '1',
        name: name,
        epgChannelId: epg,
        streamUrl: Uri.parse('http://x/1'),
      );

  test('the same name: the guide channel with programmes wins', () {
    final m = ChannelMatcher([events, real], empty: {'DAZN1.it'});
    expect(m.match(ch('IT: DAZN 1 HD'))!.guideChannelId, 'DAZN.1.it.it');
    // Without the hint, the first listed, as before.
    expect(ChannelMatcher([events, real]).match(ch('DAZN 1'))!.guideChannelId,
        'DAZN1.it');
  });

  test('an id with nothing to show gives way to a name that has', () {
    final m = ChannelMatcher([events, real], empty: {'DAZN1.it'});
    final hit = m.match(ch('DAZN 1', epg: 'dazn1.it'))!;
    expect(hit.guideChannelId, 'DAZN.1.it.it');
    // Nothing better by name: the id given stays.
    expect(
        m.match(ch('Something', epg: 'DAZN1.it'))!.guideChannelId, 'DAZN1.it');
  });

  test('fillers are told by their titles', () {
    expect(isFillerTitle(' No Game Today '), isTrue);
    expect(isFillerTitle('Nessun evento in onda'), isTrue);
    expect(isFillerTitle('Sassuolo - Genoa'), isFalse);
  });
}
