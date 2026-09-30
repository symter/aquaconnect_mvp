import 'package:flutter/material.dart';

import '../../data/models/farm.dart';
import '../theme/app_colors.dart';
import 'risk_badge.dart';

class FarmCard extends StatelessWidget {
  const FarmCard({super.key, required this.farm, required this.onTap});

  final Farm farm;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final headlineColor = farm.riskLevel.accent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        farm.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        farm.address,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    RiskBadge(level: farm.riskLevel),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.neutralArrow),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                if (farm.headline.isNotEmpty) ...[
                  Text(
                    farm.headline,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: headlineColor),
                  ),
                  const SizedBox(width: 16),
                ],
                Text(farm.waterTemp == null ? '수온 -' : '수온 ${farm.waterTemp!.toStringAsFixed(1)}℃',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(width: 16),
                Text(farm.lastVisitDays == null ? '방문 기록 없음' : '방문 D-${farm.lastVisitDays}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
