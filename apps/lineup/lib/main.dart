import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';

import 'src/library.dart';
import 'src/screens/add_source_screen.dart';
import 'src/screens/channels_screen.dart';
import 'src/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(LineupApp(library: Library()));
}

class LineupApp extends StatelessWidget {
  const LineupApp({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      // TV remotes send Select; make it behave like Enter everywhere.
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
      },
      child: MaterialApp(
        title: 'Lineup',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: ListenableBuilder(
          listenable: library,
          builder: (context, _) => library.isEmpty
              ? AddSourceScreen(library: library)
              : ChannelsScreen(library: library),
        ),
      ),
    );
  }
}
