import 'package:flutter/material.dart';

import '../l10n.dart';
import '../playback/playback_engine.dart';
import '../theme.dart';

const _languageNames = {
  'ita': 'Italiano',
  'it': 'Italiano',
  'eng': 'English',
  'en': 'English',
  'deu': 'Deutsch',
  'ger': 'Deutsch',
  'de': 'Deutsch',
  'fra': 'Français',
  'fre': 'Français',
  'fr': 'Français',
  'spa': 'Español',
  'es': 'Español',
  'por': 'Português',
  'pt': 'Português',
};

String _trackName(BuildContext context, MediaTrack t, int n) {
  final lang = _languageNames[t.language?.toLowerCase()] ?? t.language;
  final label = t.label;
  if (label != null && label.isNotEmpty && label != t.language) {
    return lang == null || label.contains(lang) ? label : '$label ($lang)';
  }
  return lang?.toUpperCase() == lang && lang != null
      ? lang
      : lang ?? context.l10n.trackNumber(n);
}

/// Audio languages and, where the engine shows them, subtitles, in a
/// bottom sheet.
Future<void> showTracksSheet(
  BuildContext context,
  PlaybackEngine engine, {
  VoidCallback? onPicked,
}) async {
  final audio = await engine.audioTracks();
  final subtitles = await engine.subtitleTracks();
  if (!context.mounted) return;
  final l = context.l10n;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheet) {
      void pick(Future<void> Function() select) {
        Navigator.of(sheet).pop();
        select();
        onPicked?.call();
      }

      return SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Text(
                l.audio,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (audio.length < 2)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  l.noOtherTracks,
                  style: const TextStyle(color: ZaplineColors.textMuted),
                ),
              )
            else
              for (final (i, t) in audio.indexed)
                ListTile(
                  leading: Icon(
                    t.selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: t.selected ? ZaplineColors.focus : null,
                  ),
                  title: Text(_trackName(context, t, i + 1)),
                  onTap: () => pick(() => engine.selectAudioTrack(t.id)),
                ),
            if (subtitles.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                child: Text(
                  l.subtitles,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  subtitles.any((t) => t.selected)
                      ? Icons.radio_button_off_rounded
                      : Icons.radio_button_checked_rounded,
                ),
                title: Text(l.subtitlesOff),
                onTap: () => pick(() => engine.selectSubtitleTrack(null)),
              ),
              for (final (i, t) in subtitles.indexed)
                ListTile(
                  leading: Icon(
                    t.selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: t.selected ? ZaplineColors.focus : null,
                  ),
                  title: Text(_trackName(context, t, i + 1)),
                  onTap: () => pick(() => engine.selectSubtitleTrack(t.id)),
                ),
            ],
          ],
        ),
      );
    },
  );
}
