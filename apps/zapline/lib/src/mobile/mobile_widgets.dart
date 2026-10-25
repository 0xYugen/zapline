import 'package:flutter/material.dart';
import 'package:zapline_core/zapline_core.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../channel_groups.dart';
import '../theme.dart';
import '../widgets/channel_logo.dart';
import '../widgets/channel_name.dart';
import '../widgets/pin_pad.dart';

/// Asks for the PIN and opens locked groups for this session.
Future<bool> unlockWithPin(BuildContext context, AppState state) async {
  final l = context.l10n;
  if (state.pinRetryIn case final wait?) {
    showPinWait(context, l, wait);
    return false;
  }
  final pin = await askPin(context, title: l.enterPin);
  if (pin == null || !context.mounted) return false;
  if (state.unlock(pin)) return true;
  final wait = state.pinRetryIn;
  wait == null
      ? (ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l.wrongPin))))
      : showPinWait(context, l, wait);
  return false;
}

void showPinWait(BuildContext context, AppLocalizations l, Duration wait) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.pinWait(wait.inSeconds + 1))));

/// Asks for the parental PIN when one is set and not yet entered; for
/// screens that reveal passwords or could change the PIN.
Future<bool> requirePinIfSet(BuildContext context, AppState state) async {
  if (!state.hasPin || state.unlocked) return true;
  return unlockWithPin(context, state);
}

/// Horizontal strip of group pills with a button that opens every group in
/// a searchable sheet.
class GroupBar extends StatefulWidget {
  const GroupBar({
    super.key,
    required this.state,
    required this.selected,
    required this.onSelected,
  });

  final AppState state;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  State<GroupBar> createState() => _GroupBarState();
}

class _GroupBarState extends State<GroupBar> {
  final _scroll = ScrollController();
  final _selectedKey = GlobalKey();

  @override
  void didUpdateWidget(GroupBar old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      // A group picked from the sheet may be far along the strip.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _selectedKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.3,
            duration: const Duration(milliseconds: 200),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _openSheet() async {
    final picked = await showGroupSheet(context, widget.state, widget.selected);
    if (picked != null) widget.onSelected(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupsOf(widget.state);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              tooltip: context.l10n.allGroups,
              onPressed: _openSheet,
              icon: const Icon(Icons.segment_rounded),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final g = groups[i];
                final selected = g == widget.selected;
                return Pill(
                  key: selected ? _selectedKey : null,
                  label: groupLabel(context.l10n, g),
                  icon: switch (g) {
                    favouritesGroup => Icons.star_rounded,
                    recentGroup => Icons.history_rounded,
                    _ when g != null && widget.state.isLocked(g) =>
                      Icons.lock_outline_rounded,
                    _ => null,
                  },
                  selected: selected,
                  onTap: () => widget.onSelected(g),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class Pill extends StatefulWidget {
  const Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<Pill> createState() => _PillState();
}

class _PillState extends State<Pill> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final icon = widget.icon;
    final label = widget.label;
    final fg = selected ? ZaplineColors.onFocus : ZaplineColors.text;
    return Material(
      color: selected ? ZaplineColors.focus : ZaplineColors.surfaceHigh,
      shape: StadiumBorder(
        side: _focused
            ? const BorderSide(color: ZaplineColors.focusBorder, width: 2.5)
            : BorderSide.none,
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: widget.onTap,
        onFocusChange: (f) {
          setState(() => _focused = f);
          if (f) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 150),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Every group in a bottom sheet, with a filter field when there are many.
/// Returns the picked group wrapped in a record (`null` group = all).
Future<({String? value})?> showGroupSheet(
  BuildContext context,
  AppState state,
  String? selected,
) => showModalBottomSheet<({String? value})>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => _GroupSheet(state: state, selected: selected),
);

class _GroupSheet extends StatefulWidget {
  const _GroupSheet({required this.state, required this.selected});

  final AppState state;
  final String? selected;

  @override
  State<_GroupSheet> createState() => _GroupSheetState();
}

class _GroupSheetState extends State<_GroupSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final all = groupsOf(widget.state);
    final f = _filter.trim().toLowerCase();
    final groups = f.isEmpty
        ? all
        : [
            for (final g in all)
              if (groupLabel(context.l10n, g).toLowerCase().contains(f)) g,
          ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                context.l10n.groups,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          if (all.length > 12)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autocorrect: false,
                onChanged: (v) => setState(() => _filter = v),
                decoration: InputDecoration(
                  hintText: context.l10n.findGroup,
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: groups.length,
              itemBuilder: (context, i) {
                final g = groups[i];
                final locked = g != null && widget.state.isLocked(g);
                return ListTile(
                  selected: g == widget.selected,
                  selectedColor: ZaplineColors.focus,
                  leading: Icon(switch (g) {
                    null => Icons.apps_rounded,
                    favouritesGroup => Icons.star_rounded,
                    recentGroup => Icons.history_rounded,
                    _ => Icons.folder_outlined,
                  }),
                  title: Text(
                    groupLabel(context.l10n, g),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: locked
                      ? const Icon(Icons.lock_outline_rounded, size: 18)
                      : null,
                  onTap: () => Navigator.of(context).pop((value: g)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One channel in a phone list: logo, number and name, what's on now with
/// its progress, and favourite / catch-up markers.
class MobileChannelRow extends StatelessWidget {
  const MobileChannelRow({
    super.key,
    required this.state,
    required this.channel,
    required this.number,
    required this.onTap,
    required this.onLongPress,
  });

  static const height = 76.0;

  final AppState state;
  final Channel channel;
  final int number;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = channel;
    final (now, _) = state.nowNext(c);
    final t = DateTime.now();
    final progress = now == null
        ? null
        : (t.difference(now.start).inSeconds /
                  now.stop.difference(now.start).inSeconds)
              .clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ChannelLogo(channel: c, width: 64, height: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$number',
                        style: const TextStyle(
                          fontSize: 13,
                          color: ZaplineColors.textMuted,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChannelName(
                          state: state,
                          channel: c,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          now?.title ?? context.l10n.noGuide,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: ZaplineColors.textMuted,
                          ),
                        ),
                      ),
                      if (now != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.timeLeft(now.stop.difference(t)),
                          style: const TextStyle(
                            fontSize: 12,
                            color: ZaplineColors.textMuted,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 3,
                        color: ZaplineColors.focus,
                        backgroundColor: ZaplineColors.line,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (state.isFavourite(c))
              const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: ZaplineColors.focus,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Shown instead of a locked group's channels.
class LockedGroupView extends StatelessWidget {
  const LockedGroupView({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 48,
            color: ZaplineColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.groupLocked,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => unlockWithPin(context, state),
            icon: const Icon(Icons.lock_open_rounded),
            label: Text(context.l10n.unlockWithPin),
          ),
        ],
      ),
    ),
  );
}

/// A short centred message for empty lists.
class EmptyView extends StatelessWidget {
  const EmptyView(this.text, {super.key, this.icon = Icons.tv_off_outlined});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: ZaplineColors.textMuted),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ZaplineColors.textMuted),
          ),
        ],
      ),
    ),
  );
}
