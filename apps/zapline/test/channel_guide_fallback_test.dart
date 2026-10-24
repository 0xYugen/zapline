import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zapline/main.dart';
import 'package:zapline/src/app_state.dart';
import 'package:zapline_data/zapline_data.dart';

import 'helpers.dart';

void main() {
  testWidgets('channels without EPG get now/next from the source', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    final db = ZaplineDatabase.inMemory();
    final asked = <String>[];
    final fetcher = ChannelGuideFetcher(
      db,
      httpClient: MockClient((req) async {
        final id = req.url.queryParameters['stream_id']!;
        asked.add(id);
        final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        return http.Response(
          jsonEncode({
            'epg_listings': [
              {
                'title': 'Live show $id',
                'start_timestamp': '${now - 600}',
                'stop_timestamp': '${now + 1200}',
              },
            ],
          }),
          200,
        );
      }),
    );
    final state = fakeState(
      count: 4,
      unmatched: {3},
      database: db,
      guideFetcher: fetcher,
    );
    await state.addSource(
      const SourceInput(url: 'http://x.example/get.php?username=a&password=b'),
    );
    expect(state.coverage(state.sources.single.id).matched, 3);

    await tester.pumpWidget(ZaplineApp(state: state));
    await tester.pumpAndSettle();
    // Only the channel the XMLTV guide misses is asked for, once.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(asked, ['3']);
    expect(find.text('Live show 3'), findsOneWidget);

    // The source card explains where the guide came from.
    final status = state.guideStatus(state.sources.single.id)!;
    expect(status.programmes, greaterThan(0));
    expect(status.perChannel, isTrue);
  });
}
