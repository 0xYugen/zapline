import 'package:zapline_core/zapline_core.dart';

import '../l10n/app_localizations.dart';

/// Turns network and server errors into something a viewer can act on.
String friendlyError(AppLocalizations l, Object e) {
  final raw = redactSecrets(e.toString().replaceFirst('Exception: ', ''));
  final lower = raw.toLowerCase();
  if (lower.contains('already added')) return l.errorDuplicate;
  if (lower.contains('failed host lookup') ||
      lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('timed out') ||
      lower.contains('timeoutexception') ||
      lower.contains('network is unreachable')) {
    return l.errorUnreachable;
  }
  if (lower.contains('401') ||
      lower.contains('403') ||
      lower.contains('auth') ||
      lower.contains('credential')) {
    return l.errorLogin;
  }
  if (lower.contains('404')) return l.errorNotFound;
  return l.errorGeneric(raw);
}
