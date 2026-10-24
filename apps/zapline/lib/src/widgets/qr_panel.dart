import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../pairing/pin_server.dart';
import '../l10n.dart';
import '../theme.dart';

/// QR code, address and PIN of a [PinServer], for a phone or PC browser.
class QrPanel extends StatelessWidget {
  const QrPanel({
    super.key,
    required this.server,
    required this.title,
    required this.subtitle,
  });

  final PinServer server;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: ZaplineColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZaplineColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: ZaplineColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 18),
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: server.url.toString(),
                size: 200,
                padding: EdgeInsets.zero,
                semanticsLabel: context.l10n.qrLabel,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.orOpenOnPhone,
            style: TextStyle(color: ZaplineColors.textMuted, fontSize: 14),
          ),
          Text(
            server.shortUrl,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.code,
            style: TextStyle(color: ZaplineColors.textMuted, fontSize: 14),
          ),
          Text(
            server.pin,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: ZaplineColors.focus,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
