import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool showWordmark;

  const AppLogo({super.key, this.size = 44, this.showWordmark = false});

  @override
  Widget build(BuildContext context) {
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.tealSoft,
            borderRadius: BorderRadius.circular(size * 0.24),
          ),
          child: Icon(Icons.health_and_safety_rounded, color: AppColors.teal, size: size * 0.58),
        ),
      ),
    );

    if (!showWordmark) return logo;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        Text(
          'HealthMate',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class AppStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const AppStatusChip({
    super.key,
    required this.label,
    this.color = AppColors.slate,
    this.background = const Color(0xFFF0F5F3),
    this.icon,
  });

  factory AppStatusChip.success(String label) => AppStatusChip(
        label: label,
        color: AppColors.success,
        background: AppColors.successSoft,
        icon: Icons.cloud_done_outlined,
      );

  factory AppStatusChip.warning(String label) => AppStatusChip(
        label: label,
        color: AppColors.warning,
        background: AppColors.warningSoft,
        icon: Icons.cloud_off_outlined,
      );

  factory AppStatusChip.neutral(String label) => AppStatusChip(
        label: label,
        color: AppColors.slate,
        background: const Color(0xFFF0F5F3),
        icon: Icons.devices_outlined,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.tealSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.teal, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.danger, size: 30),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppInfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  final Widget? trailing;

  const AppInfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.color = AppColors.tealDark,
    this.background = AppColors.tealSoft,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13, height: 1.45),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class AppSkeletonBox extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const AppSkeletonBox({
    super.key,
    this.height = 14,
    this.width = double.infinity,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8F0ED),
      highlightColor: const Color(0xFFF7FBFA),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ArticleSkeleton extends StatelessWidget {
  const ArticleSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppSkeletonBox(height: 82, width: 82, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppSkeletonBox(height: 16),
                  SizedBox(height: 8),
                  AppSkeletonBox(height: 12),
                  SizedBox(height: 6),
                  AppSkeletonBox(height: 12, width: 180),
                  SizedBox(height: 12),
                  AppSkeletonBox(height: 10, width: 120),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message, {bool isError = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isError ? AppColors.danger : AppColors.navy,
    ),
  );
}

Future<bool> openExternalUrl(BuildContext context, String? rawUrl, {String? failureMessage}) async {
  final raw = rawUrl?.trim() ?? '';
  if (raw.isEmpty) {
    showAppSnackBar(context, failureMessage ?? 'No link is available for this item.', isError: true);
    return false;
  }
  var candidate = raw;
  if (candidate.startsWith('//')) candidate = 'https:$candidate';
  if (!candidate.startsWith('http')) candidate = 'https://$candidate';
  final uri = Uri.tryParse(candidate);
  if (uri == null || !uri.hasAbsolutePath && uri.host.isEmpty) {
    showAppSnackBar(context, failureMessage ?? 'This link is not valid.', isError: true);
    return false;
  }
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (context.mounted) {
        showAppSnackBar(context, failureMessage ?? 'Could not open this link.', isError: true);
      }
      return false;
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      showAppSnackBar(context, failureMessage ?? 'Could not open this link.', isError: true);
    }
    return false;
  }
}

String formatShortDate(DateTime date, AppLocalizations l10n) {
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return l10n.t('just_now');
  if (difference.inMinutes < 60) return '${difference.inMinutes}m';
  if (difference.inHours < 24) return '${difference.inHours}h';
  if (difference.inDays == 1) return l10n.t('yesterday');
  if (difference.inDays < 7) return '${difference.inDays}d';
  return '${date.day}/${date.month}/${date.year}';
}

String formatDateTime(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String formatDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month && start.day == end.day) {
    return formatDateTime(start);
  }
  return '${formatDateTime(start)} – ${formatDateTime(end)}';
}
