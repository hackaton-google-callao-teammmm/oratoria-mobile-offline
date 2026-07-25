import 'package:flutter/material.dart';

import '../../../app/theme/tokens.dart';

/// A subtle live caption of what the child is saying, shown during EXPONIENDO.
///
/// Deliberately low-emphasis and marked "en vivo · aprox": it is a mirror, not
/// a correction, so it respects the golden rule (no corrective text while
/// speaking) and never competes with La Banca / the eq-waveform for attention.
/// The words are streaming, best-effort STT — they are cosmetic and never feed
/// the report, which stays on the final Whisper pass.
class LiveCaption extends StatelessWidget {
  final String text;

  const LiveCaption({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final t = AppTokens.of(context);
    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: t.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record_rounded,
                  size: 8, color: t.accent),
              const SizedBox(width: 6),
              Text(
                'EN VIVO · APROX',
                style: TextStyle(
                  color: t.inkFaint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            trimmed,
            softWrap: true,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: t.inkSoft, fontSize: 15, height: 1.25),
          ),
        ],
      ),
    );
  }
}
