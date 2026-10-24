import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

export '../l10n/app_localizations.dart';

/// `context.l10n.someText`: the UI strings in the device language (Italian
/// or English for now; see lib/l10n/*.arb).
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
