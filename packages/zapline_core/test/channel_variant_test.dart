import 'package:test/test.dart';
import 'package:zapline_core/zapline_core.dart';

void main() {
  ChannelVariant v(String s) => ChannelVariant.parse(s);

  test('quality words split off the name', () {
    expect(v('Rai 1 HD').baseName, 'Rai 1');
    expect(v('Rai 1 HD').quality, VideoQuality.hd);
    expect(v('RAI 1 FHD').quality, VideoQuality.fhd);
    expect(v('IT | Rai 1 4K').baseName, 'IT | Rai 1');
    expect(v('IT | Rai 1 4K').quality, VideoQuality.uhd);
    expect(v('Canale 5 (1080p)').baseName, 'Canale 5');
    expect(v('Sky Sport Uno ᴴᴰ').quality, VideoQuality.hd);
    expect(v('Italia 1 Full HD').quality, VideoQuality.fhd);
    expect(v('Rete 4 HEVC').baseName, 'Rete 4');
    expect(v('Rete 4 H.265').baseName, 'Rete 4');
    expect(v('La7 [backup]').baseName, 'La7');
    expect(v('La7').quality, VideoQuality.unknown);
  });

  test('versions of a channel share a key', () {
    final keys = {
      for (final n in ['Rai 1', 'RAI 1 HD', 'Rai 1 FHD', 'Rai 1 (backup)'])
        v(n).key,
    };
    expect(keys, hasLength(1));
    expect(v('IT | Rai 1 HD').key, v('IT: RAI 1 4K').key);
  });

  test('different channels keep different keys', () {
    expect(v('Rai 1').key, isNot(v('Rai 1 +1').key));
    expect(v('Rai 1').key, isNot(v('Rai 2').key));
    expect(v('Rai 4').key, isNot(v('Rai 4K').key));
  });

  test('a name made only of quality words stays whole', () {
    expect(v('4K').baseName, '4K');
    expect(v('HD').key, isNot(v('SD').key));
  });
}
