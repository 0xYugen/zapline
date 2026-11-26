import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  test('a release whose package is not attached yet is no update', () async {
    final updater = Updater(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({...release, 'tag_name': 'v0.1.0-114', 'assets': []}),
          200,
        ),
      ),
    );
    // Android installs from inside the app; elsewhere the page is enough.
    final update = await updater.check(68);
    if (Updater.installsInApp) {
      expect(update, isNull);
    } else {
      expect(update!.build, 114);
      expect(update.apk, isNull);
    }
    // An empty address saved by an older version is no address.
    expect(
      AppUpdate.fromJson({
        'build': 114,
        'version': '0.1.0 (114)',
        'page': 'https://x.test',
        'apk': '',
      })!.apk,
      isNull,
    );
  });

  test('when the API refuses, the release page and its links', () async {
    final asked = <String>[];
    final updater = Updater(
      httpClient: MockClient((req) async {
        asked.add('${req.method} ${req.url.host}${req.url.path}');
        if (req.url.host == 'api.github.com') {
          return http.Response('rate limited', 403);
        }
        if (req.url.path.endsWith('/releases/latest')) {
          return http.Response(
            '',
            302,
            headers: {
              'location':
                  'https://github.com/0xYugen/zapline/releases/tag/v0.1.0-114',
            },
          );
        }
        return http.Response('', 200, headers: {'content-length': '50'});
      }),
    );
    final update = (await updater.check(68))!;
    expect(update.build, 114);
    expect(
      update.page.toString(),
      'https://github.com/0xYugen/zapline/releases/tag/v0.1.0-114',
    );
    expect(
      asked.first,
      'GET api.github.com/repos/0xYugen/zapline/releases/latest',
    );

    // Nothing answers at all: a failure, not "up to date".
    final offline = Updater(
      httpClient: MockClient((_) async => throw const SocketException('no')),
    );
    await expectLater(offline.check(68), throwsA(isA<SocketException>()));
  });
}
