import 'package:flutter/material.dart';
import '../models/station.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_text_styles.dart';

class StationCard extends StatelessWidget {
  final Station station;
  final VoidCallback onTap;

  const StationCard({super.key, required this.station, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(station.name, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(station.address, style: AppTextStyles.bodyMedium),
              if (station.detailedAddress != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  station.detailedAddress!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
