import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/widgets/channel_logo.dart';

void main() {
  test('the image cache drops the oldest files over budget', () async {
    final dir = await Directory.systemTemp.createTemp('logos');
    addTearDown(() => dir.delete(recursive: true));
    final now = DateTime.now();
    for (var i = 0; i < 10; i++) {
      final f = File('${dir.path}/$i')..writeAsBytesSync(List.filled(100, 0));
      f.setLastModifiedSync(now.subtract(Duration(minutes: 10 - i)));
    }
    await LogoCache.trim(dir, budget: 500);
    final left = dir.listSync().map((e) => e.uri.pathSegments.last).toSet();
    expect(left.length, 4);
    expect(left, containsAll(['6', '7', '8', '9']));
  });
}
