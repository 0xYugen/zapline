import 'package:flutter/material.dart';

import '../free_epg.dart';
import '../l10n.dart';
import '../layout.dart';
import '../theme.dart';
import 'focus_card.dart';

/// The country suggested from the device settings, if it has a free EPG.
FreeEpg? suggestedFreeEpg() =>
    FreeEpg.forLocale(WidgetsBinding.instance.platformDispatcher.locale);

/// Lets the user pick a country's free EPG: a searchable sheet on phones,
/// a remote-friendly list elsewhere. The device's country comes first.
Future<FreeEpg?> pickFreeEpg(BuildContext context, {FreeEpg? first}) {
  final suggested = first ?? suggestedFreeEpg();
  final list = [
    ?suggested,
    for (final c in FreeEpg.countries)
      if (c != suggested) c,
  ];
  if (context.isPhone) {
    return showModalBottomSheet<FreeEpg>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PhonePicker(list: list),
    );
  }
  return showDialog<FreeEpg>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: ZaplineColors.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.freeEpgByCountry,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.freeEpgNote,
                style: TextStyle(color: ZaplineColors.textMuted),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: FocusCard(
                      autofocus: i == 0,
                      onPressed: () => Navigator.of(dialogContext).pop(list[i]),
                      child: Text(
                        list[i].name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PhonePicker extends StatefulWidget {
  const _PhonePicker({required this.list});

  final List<FreeEpg> list;

  @override
  State<_PhonePicker> createState() => _PhonePickerState();
}

class _PhonePickerState extends State<_PhonePicker> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final f = _filter.trim().toLowerCase();
    final list = [
      for (final c in widget.list)
        if (f.isEmpty || c.name.toLowerCase().contains(f)) c,
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              context.l10n.freeEpgByCountry,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              context.l10n.freeEpgNote,
              style: TextStyle(fontSize: 13, color: ZaplineColors.textMuted),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autocorrect: false,
              onChanged: (v) => setState(() => _filter = v),
              decoration: InputDecoration(
                hintText: context.l10n.findCountry,
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: scroll,
              itemCount: list.length,
              itemBuilder: (context, i) => ListTile(
                leading: const Icon(Icons.public_rounded),
                title: Text(list[i].name),
                onTap: () => Navigator.of(context).pop(list[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
