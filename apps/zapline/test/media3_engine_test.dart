import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/playback/media3_engine.dart';

/// The Dart side of Zapline's own Android player, over fake native
/// channels: what it asks the ExoPlayer to do, and which of its events
/// count.
void main() {
  final calls = <MethodCall>[];
  late MockStreamHandlerEventSink sink;
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    calls.clear();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zapline/media3'),
      (call) async {
        calls.add(call);
        if (call.method == 'tracks') {
          return [
            {
              'id': '0:0',
              'label': 'Italiano',
              'language': 'it',
              'selected': true,
            },
            {'id': '0:1', 'label': null, 'language': 'en', 'selected': false},
          ];
        }
        return null;
      },
    );
    binding.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('zapline/media3/events'),
      MockStreamHandler.inline(
        onListen: (_, events) {
          sink = events;
        },
      ),
    );
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('zapline/media3'),
      null,
    );
    binding.defaultBinaryMessenger.setMockStreamHandler(
      const EventChannel('zapline/media3/events'),
      null,
    );
  });

  List<String> methods() => [for (final c in calls) c.method];

  test('a zap keeps the player: pause now, stop only if idle', () async {
    final e = Media3Engine();
    await e.open(
      Uri.parse('http://x.example/1.ts'),
      headers: {'User-Agent': 'Zapline'},
    );
    expect(methods(), ['create', 'open']);
    final open = calls.last.arguments as Map;
    expect(open['url'], 'http://x.example/1.ts');
    expect(open['headers'], {'User-Agent': 'Zapline'});

    // Zap: paused at once, the next channel opens in the same player.
    await e.stop();
    await e.open(Uri.parse('http://x.example/2.ts'));
    // No stop comes later for the channel left.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(methods(), ['create', 'open', 'pause', 'open']);

    // Left alone, it lets the stream go after a second.
    await e.stop();
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    expect(methods().last, 'stop');
    await e.dispose();
    expect(methods().last, 'dispose');
  });

  test('events of this player and this stream only', () async {
    final e = Media3Engine();
    final positions = <Duration>[], errors = <String>[], stalls = <bool>[];
    e.position.listen(positions.add);
    e.errors.listen(errors.add);
    e.buffering.listen(stalls.add);
    await Future<void>.delayed(Duration.zero);
    final id = (calls.first.arguments as Map)['id'];

    await e.open(Uri.parse('http://x.example/1.ts'));
    sink.success({'id': id, 'event': 'buffering', 'value': true});
    sink.success({'id': id, 'event': 'position', 'ms': 1});
    sink.success({'id': id, 'event': 'duration', 'ms': 0});
    sink.success({'id': id, 'event': 'playing', 'value': true});
    // Another player's error.
    sink.success({'id': id + 100, 'event': 'error', 'message': 'not mine'});
    await Future<void>.delayed(Duration.zero);
    expect(positions, [const Duration(milliseconds: 1)]);
    expect(stalls, [true]);
    expect(errors, isEmpty);
    expect(e.isPlaying, isTrue);

    // After a stop, the old stream's last events are dropped.
    await e.stop();
    sink.success({'id': id, 'event': 'error', 'message': 'old stream'});
    await Future<void>.delayed(Duration.zero);
    expect(errors, isEmpty);
    await e.open(Uri.parse('http://x.example/2.ts'));
    sink.success({'id': id, 'event': 'error', 'message': 'Source error'});
    await Future<void>.delayed(Duration.zero);
    expect(errors, ['Source error']);
    await e.dispose();
  });

  test('two players share the event stream; a live end is an error', () async {
    final a = Media3Engine(), b = Media3Engine();
    final aErrors = <String>[], bErrors = <String>[];
    a.errors.listen(aErrors.add);
    b.errors.listen(bErrors.add);
    await a.open(Uri.parse('http://x.example/1.ts'));
    await b.open(Uri.parse('http://x.example/movie.mp4'));
    final ids = [
      for (final c in calls)
        if (c.method == 'create') (c.arguments as Map)['id'],
    ];
    expect(ids, hasLength(2));
    sink.success({'id': ids[0], 'event': 'duration', 'ms': 0, 'live': true});
    sink.success({
      'id': ids[1],
      'event': 'duration',
      'ms': 5000,
      'live': false,
    });
    // The server closed the live stream: retried as an error.
    sink.success({'id': ids[0], 'event': 'ended'});
    // A film's end is just its end.
    sink.success({'id': ids[1], 'event': 'ended'});
    await Future<void>.delayed(Duration.zero);
    expect(aErrors, ['Stream ended']);
    expect(bErrors, isEmpty);
    // One player gone, the other still hears its events.
    await a.dispose();
    sink.success({'id': ids[1], 'event': 'error', 'message': 'Source error'});
    await Future<void>.delayed(Duration.zero);
    expect(bErrors, ['Source error']);
    await b.dispose();
  });

  test('audio and subtitle tracks', () async {
    final e = Media3Engine();
    final audio = await e.audioTracks();
    expect(audio.map((t) => t.language), ['it', 'en']);
    expect(audio.first.selected, isTrue);
    await e.selectAudioTrack('0:1');
    expect(calls.last.arguments, containsPair('track', '0:1'));
    await e.selectSubtitleTrack(null);
    expect(calls.last.arguments, containsPair('type', 'text'));
    expect((calls.last.arguments as Map)['track'], isNull);
    await e.setVolume(0.4);
    expect(calls.last.arguments, containsPair('value', 0.4));
    await e.dispose();
  });

  test('preload sends the neighbours with their places', () async {
    final e = Media3Engine();
    await e.preload(4, [
      (3, Uri.parse('http://x.example/3.ts')),
      (5, Uri.parse('http://x.example/5.ts')),
    ]);
    final args = calls.last.arguments as Map;
    expect(calls.last.method, 'preload');
    expect(args['current'], 4);
    expect(args['items'], [
      {'index': 3, 'url': 'http://x.example/3.ts'},
      {'index': 5, 'url': 'http://x.example/5.ts'},
    ]);
    await e.preload(4, const []);
    expect((calls.last.arguments as Map)['items'], isEmpty);
    await e.dispose();
  });

  test(
    'leaving the app pauses, coming back plays; not with background sound',
    () async {
      final live = Media3Engine();
      await live.open(Uri.parse('http://x.example/1.ts'));
      // A live channel is let go and opens again at live on return.
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(methods(), ['create', 'open', 'stop']);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(methods().last, 'open');
      expect((calls.last.arguments as Map)['url'], 'http://x.example/1.ts');
      await live.dispose();

      // A film pauses where it is.
      calls.clear();
      final e = Media3Engine();
      await e.open(Uri.parse('http://x.example/movie.mp4'));
      final id = (calls.first.arguments as Map)['id'];
      sink.success({'id': id, 'event': 'duration', 'ms': 5000, 'live': false});
      await Future<void>.delayed(Duration.zero);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(methods().where((m) => m == 'pause'), hasLength(1));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(methods().last, 'play');
      await e.dispose();

      calls.clear();
      final b = Media3Engine(background: true);
      expect((calls.first.arguments as Map)['background'], isTrue);
      await b.open(Uri.parse('http://x.example/1.ts'));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await Future<void>.delayed(Duration.zero);
      expect(methods(), isNot(contains('pause')));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await b.dispose();
    },
  );
}
