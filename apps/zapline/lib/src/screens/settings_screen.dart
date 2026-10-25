import 'package:flutter/material.dart';
import 'package:zapline_data/zapline_data.dart';

import '../app_state.dart';
import '../keep_awake.dart';
import '../l10n.dart';
import '../layout.dart';
import '../mobile/mobile_widgets.dart' show requirePinIfSet;
import '../theme.dart';
import '../updates.dart';
import '../widgets/brand.dart';
import '../widgets/pin_pad.dart';
import '../widgets/settings_widgets.dart';
import '../widgets/update_tile.dart';
import 'add_source_screen.dart';
import 'backup_screen.dart';
import 'transfer_screens.dart';
import 'source_detail_screen.dart';

/// App-wide preferences as a grouped list: sources first, then watching,
/// language, TV guide, privacy and about. Each row shows its current value
/// and opens a choice; per-source options live in the source's details.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get _state => widget.state;

  Future<void> _checkNow() async {
    final l = context.l10n;
    _snack(l.checkingUpdates);
    try {
      final u = await _state.checkForUpdate(now: true);
      if (!mounted) return;
      _snack(u == null ? l.upToDate : l.updateAvailable(u.version));
    } catch (_) {
      if (mounted) _snack(l.updateCheckFailed);
    }
  }

  // A new message replaces the one on screen instead of queueing.
  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Saves a preference and redraws every screen that shows it.
  void _set(void Function() change) {
    change();
    _state.settingsChanged();
    setState(() {});
  }

  Future<void> _pick<T>(
    String title,
    Map<T, String> options,
    T current,
    void Function(T) apply,
  ) async {
    final picked = await showChoice<T>(
      context,
      title: title,
      options: options,
      current: current,
    );
    if (picked != null) _set(() => apply(picked.value));
  }

  Future<void> _setPin() async {
    final l = context.l10n;
    final first = await askPin(context, title: l.choosePin);
    if (first == null || !mounted) return;
    final again = await askPin(context, title: l.enterItAgain);
    if (again == null || !mounted) return;
    if (again != first) return _snack(l.pinsDiffer);
    _state.setPin(first);
    setState(() {});
    _snack(l.pinSaved);
  }

  Future<void> _removePin() async {
    final l = context.l10n;
    final pin = await askPin(context, title: l.enterCurrentPin);
    if (pin == null || !mounted) return;
    if (!_state.unlock(pin)) return _snack(l.wrongPin);
    _state.setPin(null);
    setState(() {});
    _snack(l.pinRemoved);
  }

  Future<void> _pinMenu() async {
    final l = context.l10n;
    if (!_state.hasPin) return _setPin();
    final picked = await showChoice<String>(
      context,
      title: l.parentalPin,
      options: {
        'change': l.changePin,
        'remove': l.removePin,
        if (_state.unlocked) 'lock': l.lockNow,
      },
      current: '',
    );
    switch (picked?.value) {
      case 'change':
        await _setPin();
      case 'remove':
        await _removePin();
      case 'lock':
        _state.lock();
        setState(() {});
        _snack(l.lockedAgain);
    }
  }

  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Screens that hand out passwords or could replace the PIN ask for it.
  Future<void> _openWithPin(Widget page) async {
    if (await requirePinIfSet(context, _state) && mounted) _open(page);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final s = _state.settings;
        final fits = {
          BoxFit.contain: l.fitFit,
          BoxFit.cover: l.fitZoom,
          BoxFit.fill: l.fitStretch,
        };
        final numbering = {false: l.numbersProvider, true: l.numbersSequential};
        final quality = {false: l.qualityBest, true: l.qualitySaver};
        final days = {
          for (final d in [2, 3, 7, 14]) d: l.daysCount(d),
        };
        final refresh = {
          0: l.refreshNever,
          6: l.everyHours(6),
          12: l.everyHours(12),
          24: l.everyHours(24),
        };
        final languages = <String?, String>{
          null: l.languageDevice,
          'it': 'Italiano',
          'en': 'English',
        };
        return AdaptivePage(
          title: l.settings,
          children: [
            if (_state.update case final update?)
              SettingsGroup(
                title: l.updateGroup,
                children: [UpdateTile(state: _state, update: update)],
              ),
            SettingsGroup(
              title: l.sources,
              children: [
                for (final (i, src) in _state.sources.indexed)
                  SourceTile(
                    state: _state,
                    source: src,
                    autofocus: i == 0 && !context.isPhone,
                  ),
                SettingsTile(
                  icon: Icons.add_rounded,
                  title: l.addSource,
                  accent: true,
                  chevron: false,
                  onTap: () => _open(AddSourceScreen(state: _state)),
                ),
              ],
            ),
            SettingsGroup(
              title: l.watching,
              children: [
                SettingsSwitchTile(
                  title: l.openLastChannel,
                  subtitle: l.openLastChannelHint,
                  value: s.resumeLastChannel,
                  onChanged: (v) => _set(() => s.resumeLastChannel = v),
                ),
                SettingsTile(
                  title: l.pictureSizeSetting,
                  value: fits[s.videoFit],
                  onTap: () => _pick(
                    l.pictureSizeSetting,
                    fits,
                    s.videoFit,
                    (v) => s.videoFit = v,
                  ),
                ),
                SettingsSwitchTile(
                  title: l.keepScreenOn,
                  subtitle: l.keepScreenOnHint,
                  value: s.keepScreenOn,
                  onChanged: (v) => _set(() {
                    s.keepScreenOn = v;
                    keepScreenAwake(v);
                  }),
                ),
                SettingsSwitchTile(
                  title: l.mergeVersions,
                  subtitle: l.mergeVersionsHint,
                  value: s.mergeVersions,
                  onChanged: (v) => _set(() => s.mergeVersions = v),
                ),
                if (s.mergeVersions)
                  SettingsTile(
                    title: l.preferredQuality,
                    value: quality[s.saveData],
                    onTap: () => _pick(
                      l.preferredQuality,
                      quality,
                      s.saveData,
                      (v) => s.saveData = v,
                    ),
                  ),
                SettingsTile(
                  title: l.channelNumbers,
                  value: numbering[s.sequentialNumbers],
                  onTap: () => _pick(
                    l.channelNumbers,
                    numbering,
                    s.sequentialNumbers,
                    (v) => s.sequentialNumbers = v,
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.language,
              children: [
                ValueListenableBuilder<String?>(
                  valueListenable: s.language,
                  builder: (context, language, _) => SettingsTile(
                    icon: Icons.translate_rounded,
                    title: l.language,
                    value: languages[language],
                    onTap: () =>
                        _pick(l.language, languages, language, s.setLanguage),
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.tvGuide,
              children: [
                SettingsSwitchTile(
                  title: l.clock24h,
                  value: s.clock24h,
                  onChanged: (v) => _set(() => s.clock24h = v),
                ),
                SettingsTile(
                  title: l.daysToKeep,
                  subtitle: l.daysToKeepHint,
                  value: days[s.guideDays] ?? l.daysCount(s.guideDays),
                  onTap: () => _pick(
                    l.daysToKeep,
                    days,
                    s.guideDays,
                    (v) => s.guideDays = v,
                  ),
                ),
                SettingsTile(
                  title: l.updateAutomatically,
                  value:
                      refresh[s.refreshHours] ?? l.everyHours(s.refreshHours),
                  onTap: () => _pick(
                    l.updateAutomatically,
                    refresh,
                    s.refreshHours,
                    (v) => s.refreshHours = v,
                  ),
                ),
              ],
            ),
            SettingsGroup(
              title: l.privacyAndSafety,
              children: [
                if (!_state.passwordsInKeystore)
                  SettingsTile(
                    icon: Icons.warning_amber_rounded,
                    iconColor: ZaplineColors.focus,
                    title: l.noKeystoreTitle,
                    subtitle: l.noKeystoreHint,
                    chevron: false,
                    onTap: () {},
                  ),
                SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  title: l.parentalPin,
                  subtitle: l.parentalPinHint,
                  value: _state.hasPin ? l.on : l.off,
                  onTap: _pinMenu,
                ),
                SettingsTile(
                  icon: Icons.save_alt_rounded,
                  title: l.backupTitle,
                  onTap: () => _openWithPin(BackupScreen(state: _state)),
                ),
              ],
            ),
            SettingsGroup(
              title: l.otherDevices,
              children: [
                if (context.isPhone)
                  SettingsTile(
                    icon: Icons.send_to_mobile_rounded,
                    title: l.sendTitle,
                    subtitle: l.sendHint,
                    onTap: () =>
                        _openWithPin(TransferSendScreen(state: _state)),
                  ),
                if (_state.settings.castTokens.isNotEmpty)
                  SettingsTile(
                    icon: Icons.cast_connected_rounded,
                    title: l.castPairedPhones,
                    subtitle: l.castPairedCount(
                      _state.settings.castTokens.length,
                    ),
                    value: l.castUnpairAll,
                    chevron: false,
                    onTap: () {
                      _set(() => _state.settings.castTokens = const {});
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(l.castUnpaired)));
                    },
                  ),
                SettingsTile(
                  icon: Icons.qr_code_2_rounded,
                  title: l.receiveTitle,
                  subtitle: l.receiveHint,
                  onTap: () =>
                      _openWithPin(TransferReceiveScreen(state: _state)),
                ),
              ],
            ),
            SettingsGroup(
              title: l.about,
              children: [
                SettingsTile(
                  leading: const ZaplineMark(size: 26),
                  title: 'Zapline · $appVersion',
                  subtitle: l.aboutLine,
                  chevron: false,
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Zapline',
                    applicationVersion: appVersion,
                  ),
                ),
                if (updatesSupported && _state.updater != null) ...[
                  SettingsSwitchTile(
                    title: l.checkUpdates,
                    subtitle: l.checkUpdatesHint,
                    value: s.checkUpdates,
                    onChanged: (v) => _set(() => s.checkUpdates = v),
                  ),
                  SettingsTile(
                    icon: Icons.system_update_rounded,
                    title: l.checkUpdatesNow,
                    chevron: false,
                    onTap: _checkNow,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }
}

/// A source in a list: health dot, name, channels and guide coverage.
class SourceTile extends StatelessWidget {
  const SourceTile({
    super.key,
    required this.state,
    required this.source,
    this.autofocus = false,
  });

  final AppState state;
  final SourceRecord source;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cov = state.coverage(source.id);
    final status = state.guideStatus(source.id);
    final syncing = state.syncingSourceId == source.id;
    final healthy =
        cov.channels > 0 &&
        cov.ratio >= 0.8 &&
        (status == null || status.errors.isEmpty);
    return SettingsTile(
      autofocus: autofocus,
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: syncing
              ? ZaplineColors.focus
              : healthy
              ? ZaplineColors.ok
              : ZaplineColors.live,
        ),
      ),
      title: source.name,
      subtitle: syncing
          ? l.syncingProgress('${state.progress ?? ''}')
          : '${l.channelCount(cov.channels)} · '
                '${l.guidePercent((cov.ratio * 100).round())}',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SourceDetailScreen(state: state, sourceId: source.id),
        ),
      ),
    );
  }
}
