// The window on a desktop: full screen in and out, as the players use it.
//
//   flutter test integration_test/desktop_window_test.dart -d linux

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zapline/src/desktop_window.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('full screen in and out', (tester) async {
    if (!DesktopWindow.supported) return;
    await DesktopWindow.init();
    await tester.pumpWidget(const SizedBox());
    await DesktopWindow.toggleFullScreen();
    await tester.pump(const Duration(milliseconds: 500));
    expect(DesktopWindow.fullScreen.value, isTrue);
    expect(await windowManager.isFullScreen(), isTrue);
    await DesktopWindow.exitFullScreen();
    await tester.pump(const Duration(milliseconds: 500));
    expect(DesktopWindow.fullScreen.value, isFalse);
    expect(await windowManager.isFullScreen(), isFalse);
  });

  testWidgets('mini player: small, above others, then back', (tester) async {
    if (!DesktopWindow.supported) return;
    await DesktopWindow.init();
    await tester.pumpWidget(const SizedBox());
    final before = await windowManager.getBounds();
    await DesktopWindow.setMini(true);
    await tester.pump(const Duration(milliseconds: 500));
    expect(DesktopWindow.mini.value, isTrue);
    expect(await windowManager.isAlwaysOnTop(), isTrue);
    final small = await windowManager.getSize();
    expect(small.width, closeTo(DesktopWindow.miniSize.width, 2));
    expect(small.height, closeTo(DesktopWindow.miniSize.height, 2));

    await DesktopWindow.exitMini();
    await tester.pump(const Duration(milliseconds: 500));
    expect(DesktopWindow.mini.value, isFalse);
    expect(await windowManager.isAlwaysOnTop(), isFalse);
    expect((await windowManager.getSize()).width, closeTo(before.width, 2));
  });
}
