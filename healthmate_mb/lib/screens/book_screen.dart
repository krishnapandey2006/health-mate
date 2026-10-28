import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';
import 'nearby_screen.dart';

class BookScreen extends StatelessWidget {
  const BookScreen({super.key});

  Future<void> _call(BuildContext context, String number) async {
    final l10n = AppLocalizations.of(context);
    try {
      await SOSService.openDialer(number);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('appointments'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 760,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B6E63), Color(0xFF0F9D8A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 27),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      l10n.t('booking_unavailable_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.t('booking_unavailable_body'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 14,
                        height: 1.55,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppInfoBanner(
                icon: Icons.verified_outlined,
                text: l10n.t('booking_no_fake_slots'),
                color: AppColors.tealDark,
                background: AppColors.tealSoft,
              ),
              const SizedBox(height: 18),
              _ActionTile(
                icon: Icons.near_me_outlined,
                title: l10n.t('find_nearby_care'),
                subtitle: l10n.t('find_nearby_care_body'),
                color: AppColors.teal,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NearbyScreen()));
                },
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.call_outlined,
                title: l10n.t('call_health_helpline'),
                subtitle: '${l10n.t('call_health_helpline_body')} · 104',
                color: const Color(0xFF175CD3),
                onTap: () => _call(context, '104'),
              ),
              const SizedBox(height: 10),
              _ActionTile(
                icon: Icons.local_hospital_outlined,
                title: l10n.t('call_ambulance_108'),
                subtitle: l10n.t('ambulance_body'),
                color: AppColors.danger,
                onTap: () => _call(context, '108'),
              ),
              const SizedBox(height: 22),
              Text(
                l10n.t('before_you_call'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      _ChecklistItem(text: l10n.t('booking_checklist_1')),
                      _ChecklistItem(text: l10n.t('booking_checklist_2')),
                      _ChecklistItem(text: l10n.t('booking_checklist_3')),
                      _ChecklistItem(text: l10n.t('booking_checklist_4')),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.t('why_no_booking'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.navy,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.t('why_no_booking_body'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => openExternalUrl(context, 'https://mohfw.gov.in/'),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(l10n.t('official_health_directory')),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('booking_disclaimer'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  final String text;

  const _ChecklistItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: const BoxDecoration(
              color: AppColors.tealSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, size: 13, color: AppColors.teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
