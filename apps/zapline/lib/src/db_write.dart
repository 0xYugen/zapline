import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs a small write from the screen's thread without ever stalling it:
/// while a sync on another isolate holds the database, the write is tried
/// again a little later instead of waiting (or failing) right away.
void writeSoon(void Function() write, {int tries = 6}) {
  try {
    write();
  } catch (e) {
    if (!isBusy(e) || tries <= 1) {
      debugPrint('Write failed: $e');
      return;
    }
    Timer(
      Duration(milliseconds: 300 * (7 - tries)),
      () => writeSoon(write, tries: tries - 1),
    );
  }
}

/// SQLite's "database is locked" (SQLITE_BUSY) from another connection.
bool isBusy(Object e) {
  final s = '$e';
  return s.contains('database is locked') ||
      s.contains('SQLITE_BUSY') ||
      s.contains('code 5)') ||
      s.contains('(code 5');
}
