import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

void main() {
  XmltvChannel g(String id, String name) =>
      XmltvChannel(id: id, displayNames: [name]);
  Channel c(String name) => Channel(
        sourceId: 's',
        id: name,
        name: name,
        streamUrl: Uri.parse('http://x/1.ts'),
      );

  test('number words and trailing country words', () {
    expect(looseChannelKey('Rai Uno'), looseChannelKey('Rai 1'));
    expect(looseChannelKey('IT | Sky Sport Uno HD'),
        looseChannelKey('Sky Sport 1'));
    expect(looseChannelKey('Discovery Italia'), looseChannelKey('Discovery'));
    expect(looseChannelKey('Cielo TV'), looseChannelKey('Cielo'));
    expect(looseChannelKey('Italia 1'), isNot(looseChannelKey('1')));
    expect(looseChannelKey('Rai 1 +1'), isNot(looseChannelKey('Rai 1')));
  });

  test('the matcher uses loose names only when unambiguous', () {
    final m = ChannelMatcher([
      g('Rai1.it', 'Rai 1'),
      g('SkySport1.it', 'Sky Sport 1'),
      g('Cielo.it', 'Cielo'),
      g('CieloSvizzera.ch', 'Cielo TV Svizzera'),
    ]);
    expect(m.match(c('RAI UNO'))?.guideChannelId, 'Rai1.it');
    expect(m.match(c('IT: Sky Sport Uno FHD'))?.guideChannelId, 'SkySport1.it');
    expect(m.match(c('Cielo TV'))?.guideChannelId, 'Cielo.it');
  });

  test('two guide channels with the same loose name match neither', () {
    final m = ChannelMatcher([
      g('a', 'Discovery Italia'),
      g('b', 'Discovery Channel'),
    ]);
    expect(m.match(c('Discovery TV')), isNull);
  });
}
