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
    final m = ChannelMatcher([events, real], programmes: {'DAZN.1.it.it': 40});
    expect(m.match(ch('IT: DAZN 1 HD'))!.guideChannelId, 'DAZN.1.it.it');
    // Without the hint, the first listed, as before.
    expect(ChannelMatcher([events, real]).match(ch('DAZN 1'))!.guideChannelId,
        'DAZN1.it');
  });

  test('an id with nothing to show gives way to a name that has', () {
    final m = ChannelMatcher([events, real], programmes: {'DAZN.1.it.it': 40});
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

  test('ids and names written like ids', () {
    expect(guideIdName('Canale5.it'), 'Canale5');
    expect(guideIdName('DAZN.1.it.it'), 'DAZN 1');
    expect(guideIdName('Rai.1.HD..101.it'), 'Rai 1 HD');
    expect(guideIdName('Rai 4K.it'), 'Rai 4K');
    expect(guideIdName('Super!.it'), 'Super!');
    expect(withoutCountrySuffix('Virgin Radio.it'), 'Virgin Radio');
    expect(withoutCountrySuffix('Dr. House'), 'Dr. House');
    // Rai 4K no longer lands on the first "Rai..." of such a guide.
    final m = ChannelMatcher(const [
      XmltvChannel(id: 'Rai.1.HD..101.it', displayNames: ['Rai 1 HD  101']),
      XmltvChannel(id: 'Rai 4K.it', displayNames: ['Rai 4K.it']),
    ]);
    expect(
      m
          .match(Channel(
            sourceId: 's',
            id: '1',
            name: 'IT: Rai 4K',
            streamUrl: Uri.parse('http://x/1'),
          ))!
          .guideChannelId,
      'Rai 4K.it',
    );
  });

  test('of two guides with programmes, the fuller one', () {
    const a =
        XmltvChannel(id: 'Rai.News.24..508.it', displayNames: ['Rai News 24']);
    const b = XmltvChannel(id: 'RaiNews24.it', displayNames: ['Rai News 24']);
    final m = ChannelMatcher([a, b], programmes: {a.id: 110, b.id: 291});
    final c = Channel(
        sourceId: 's',
        id: '1',
        name: 'Rai News 24',
        streamUrl: Uri.parse('http://x/1'));
    expect(m.match(c)!.guideChannelId, 'RaiNews24.it');
  });

  test('one channel in two guides is not ambiguous; two channels are', () {
    Channel c(String n) => Channel(
        sourceId: 's', id: n, name: n, streamUrl: Uri.parse('http://x/1'));
    final m = ChannelMatcher(const [
      XmltvChannel(id: 'Virgin.Radio.it', displayNames: ['Virgin Radio']),
      XmltvChannel(id: 'Virgin Radio.it', displayNames: ['Virgin Radio.it']),
    ]);
    expect(
        m.match(c('IT: Virgin Radio TV'))!.guideChannelId, 'Virgin.Radio.it');
    final two = ChannelMatcher(const [
      XmltvChannel(id: 'a', displayNames: ['Cielo']),
      XmltvChannel(id: 'b', displayNames: ['Cielo Italia']),
    ]);
    // "Cielo TV" could be either: left for the user to pick.
    expect(two.match(c('Cielo TV')), isNull);
  });
}
