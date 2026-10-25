import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/updates.dart';

void main() {
  final release = {
    'tag_name': 'v0.1.0-60',
    'html_url': 'https://github.com/0xYugen/zapline/releases/tag/v0.1.0-60',
    'assets': [
      {
        'name': 'zapline-tv.apk',
        'browser_download_url': 'https://example.test/zapline-tv.apk',
        'size': 50,
      },
      {
        'name': 'zapline-phone.apk',
        'browser_download_url': 'https://example.test/zapline-phone.apk',
        'size': 25,
      },
    ],
  };

  test('reads the build and the package from a release', () {
    final u = AppUpdate.fromRelease(release, tv: true)!;
    expect(u.build, 60);
    expect(u.version, '0.1.0 (60)');
    expect(u.apk.toString(), 'https://example.test/zapline-tv.apk');
    expect(u.apkSize, 50);
    expect(AppUpdate.fromJson(u.toJson())!.apk, u.apk);
  });

  test('build numbers come from the version label', () {
    expect(buildOf('0.1.0 (54)'), 54);
    expect(buildOf('development build'), isNull);
  });

  test('a tag without a build number is not an update', () {
    expect(
      AppUpdate.fromRelease({...release, 'tag_name': 'v1'}, tv: false),
      isNull,
    );
  });
}
