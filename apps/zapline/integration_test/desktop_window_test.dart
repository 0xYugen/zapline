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
}
