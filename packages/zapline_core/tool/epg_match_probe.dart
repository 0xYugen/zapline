// Dev probe: how many typical provider channel names match a real guide.
//   dart run tool/epg_match_probe.dart <guide.xml.gz>...
import 'dart:io';

import 'package:zapline_core/zapline_core.dart';

const providerNames = [
  'IT: RAI 1 FHD',
  'IT: RAI 2 HD',
  'IT: RAI 3',
  'IT | Rete 4 HD',
  'IT | Canale 5 HD',
  'IT | Italia 1 FHD',
  'IT: LA7 HD',
  'IT: TV8 HD',
  'IT: NOVE HD',
  'IT: Rai News 24',
  'IT: SKY TG24',
  'IT: Sky Sport Uno FHD',
  'IT: Sky Sport Calcio',
  'IT: Sky Cinema Uno HD',
  'IT: Sky Uno HD',
  'IT: DAZN 1',
  'IT: Real Time',
  'IT: Focus',
  'IT: Cielo',
  'IT: Iris',
  'IT: 20 Mediaset',
  'IT: Rai Movie',
  'IT: Rai Premium',
  'IT: Boing',
  'IT: Discovery Channel',
  'IT: Eurosport 1 HD',
  'IT: Rai 4',
  'IT: Rai 5',
  'IT: Rai Storia',
  'IT: Rai Gulp',
  'IT: Rai Yoyo',
  'IT: Rai Sport',
  'IT: Mediaset Extra',
  'IT: La5',
  'IT: Cine34',
  'IT: Top Crime',
  'IT: Giallo',
  'IT: DMAX',
  'IT: Food Network',
  'IT: K2',
  'IT: Frisbee',
  'IT: Cartoonito',
  'IT: Super!',
  'IT: Rai Scuola',
  'IT: TV2000',
  'IT: Sky Atlantic HD',
  'IT: Sky Serie',
  'IT: Sky Cinema Collection',
  'IT: Sky Sport F1',
  'IT: Sky Sport MotoGP',
  'IT: Sky Arte',
  'IT: Sky Nature',
  'IT: Sky Documentaries',
  'IT: Sky Investigation',
  'IT: Comedy Central',
  'IT: MTV',
  'IT: Nickelodeon',
  'IT: Cartoon Network',
  'IT: Boomerang',
  'IT: Warner TV',
];

Future<void> main(List<String> args) async {
  final guide = <XmltvChannel>[];
  for (final path in args) {
    var bytes = File(path).readAsBytesSync();
    if (bytes[0] == 0x1f && bytes[1] == 0x8b)
      bytes = gzip.decode(bytes) as dynamic;
    await for (final item in XmltvParser().parseBytes(Stream.value(bytes))) {
      if (item is XmltvChannel) guide.add(item);
    }
  }
  final m = ChannelMatcher(guide);
  final missed = <String>[];
  for (final (i, n) in providerNames.indexed) {
    final c = Channel(
        sourceId: 's', id: '$i', name: n, streamUrl: Uri.parse('http://x/$i'));
    if (m.match(c) == null) missed.add(n);
  }
  print('${args.map((a) => a.split(RegExp(r'[\/]')).last).join(' + ')}: '
      '${providerNames.length - missed.length}/${providerNames.length} matched');
  print('  missed: ${missed.join(', ')}');
}
