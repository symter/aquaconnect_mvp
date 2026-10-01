import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dimmed full-body text overlay used for the first-run welcome and the
/// one-time per-tab intros. Covers the page body only, so the bottom nav
/// stays tappable and the card can point at a tab just below it.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.primaryLabel,
    required this.onPrimary,
    this.onSkip,
    this.pointsDown = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String primaryLabel;
  final VoidCallback onPrimary;

  /// Shown as a "건너뛰기" text button when non-null.
  final VoidCallback? onSkip;

  /// Adds a down-arrow under the card, for intros that describe a bottom tab.
  final bool pointsDown;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: ColoredBox(
          color: Colors.black54,
          child: SafeArea(
            child: Align(
              alignment: pointsDown ? Alignment.bottomCenter : Alignment.center,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(color: AppColors.brandTint, shape: BoxShape.circle),
                            child: Icon(icon, size: 21, color: AppColors.brand),
                          ),
                          const SizedBox(height: 12),
                          Text(title,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          const SizedBox(height: 6),
                          Text(body, style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              if (onSkip != null)
                                TextButton(
                                  onPressed: onSkip,
                                  child: const Text('건너뛰기',
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                                ),
                              const Spacer(),
                              FilledButton(
                                onPressed: onPrimary,
                                style: FilledButton.styleFrom(backgroundColor: AppColors.brand),
                                child: Text(primaryLabel, style: const TextStyle(fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (pointsDown) const Icon(Icons.arrow_drop_down, size: 40, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
