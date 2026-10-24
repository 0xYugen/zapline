import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/vod/vod_detail_screens.dart';

void main() {
  test('trailers from a YouTube id or a link', () {
    expect(
      trailerUrl('dQw4w9WgXcQ').toString(),
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    expect(
      trailerUrl(' https://youtu.be/abc ').toString(),
      'https://youtu.be/abc',
    );
    expect(trailerUrl(''), isNull);
    expect(trailerUrl(null), isNull);
    expect(trailerUrl('not a trailer'), isNull);
  });
}
