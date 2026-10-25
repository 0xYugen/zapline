import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../theme.dart';
import 'focus_card.dart';
import 'free_epg_picker.dart';

/// After adding a source with a thin guide, offers the free EPG of its
/// country once. Call from a home screen after it is built.
Future<void> offerFreeEpgIfUseful(BuildContext context, AppState state) async {
  final source = state.takeEpgSuggestion();
  if (source == null) return;
  final epg = state.likelyFreeEpg(source.id) ?? suggestedFreeEpg();
  if (epg == null || !context.mounted) return;
  final l = context.l10n;
  final cov = state.coverage(source.id);
  final add = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black87,
    builder: (ctx) => Dialog(
      backgroundColor: ZaplineColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.event_available_rounded,
                size: 40,
                color: ZaplineColors.focus,
              ),
              const SizedBox(height: 12),
              Text(
                l.epgOfferTitle,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.epgOfferMessage(cov.channels - cov.matched, epg.name),
                style: const TextStyle(color: ZaplineColors.textMuted),
              ),
              const SizedBox(height: 20),
              FocusCard(
                autofocus: true,
                selected: true,
                onPressed: () => Navigator.of(ctx).pop(true),
                child: Center(
                  child: Text(
                    l.addFreeEpgFor(epg.name),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FocusCard(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Center(child: Text(l.notNow)),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  if (add != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l.loadingFreeEpg(epg.name))));
  try {
    final r = await state.addFreeEpg(source, epg);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            l.freeEpgAdded(epg.name, r.coverage.matched, r.coverage.channels),
          ),
        ),
      );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(content: Text(l.refreshFailed(redactSecrets('$e')))),
    );
  }
}
