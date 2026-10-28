import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../services/profile_provider.dart';
import '../widgets/app_widgets.dart';
import 'profile_setup_screen.dart';
import 'report_history_screen.dart';
import 'settings_screen.dart';
import 'vaccine_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen(isEdit: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('profile'))),
        body: AppEmptyState(
          icon: Icons.person_outline_rounded,
          title: l10n.t('profile_missing_title'),
          message: l10n.t('profile_missing_body'),
          actionLabel: l10n.t('complete_profile'),
          onAction: () => _edit(context),
        ),
      );
    }

    final age = profile.age;
    final ageText = age == null
        ? l10n.t('not_set')
        : l10n.t('age_years').replaceAll('{years}', '$age');

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('profile')),
        actions: [
          IconButton(
            tooltip: l10n.t('settings_title'),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: l10n.t('edit_profile'),
            onPressed: () => _edit(context),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: profileProvider.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: ResponsiveBody(
            maxWidth: 820,
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ProfileHeader(
                  profileProvider: profileProvider,
                  onEdit: () => _edit(context),
                ),
                const SizedBox(height: 14),
                AppInfoBanner(
                  icon: Icons.smartphone_outlined,
                  text: l10n.t('profile_device_only'),
                  color: AppColors.slate,
                  background: const Color(0xFFF0F5F3),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.t('personal_details'), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 14),
                        _InfoRow(icon: Icons.mail_outline_rounded, label: l10n.t('email'), value: profile.email.isEmpty ? l10n.t('not_set') : profile.email),
                        _InfoRow(icon: Icons.phone_outlined, label: l10n.t('phone'), value: profile.phone.isEmpty ? l10n.t('not_set') : profile.phone),
                        _InfoRow(
                          icon: Icons.cake_outlined,
                          label: l10n.t('date_of_birth'),
                          value: profile.dateOfBirth == null ? l10n.t('not_set') : formatDateTime(profile.dateOfBirth!),
                        ),
                        _InfoRow(icon: Icons.hourglass_empty_rounded, label: l10n.t('age_from_dob'), value: ageText),
                        _InfoRow(icon: Icons.wc_outlined, label: l10n.t('gender'), value: _genderLabel(l10n, profile.gender)),
                        _InfoRow(icon: Icons.location_on_outlined, label: l10n.t('state_region'), value: profile.state.isEmpty ? l10n.t('not_set') : profile.state),
                        _InfoRow(icon: Icons.translate_rounded, label: l10n.t('preferred_language'), value: _languageLabel(profile.languageCode)),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.t('age_derived_note'),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.vaccines_outlined, color: AppColors.teal),
                        title: Text(l10n.t('vaccine_records')),
                        subtitle: Text(l10n.t('vaccine_records_body')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VaccineScreen()));
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.receipt_long_outlined, color: AppColors.teal),
                        title: Text(l10n.t('report_history')),
                        subtitle: Text(l10n.t('report_history_body')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReportHistoryScreen()));
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.settings_outlined, color: AppColors.teal),
                        title: Text(l10n.t('settings_title')),
                        subtitle: Text(l10n.t('settings_body')),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.t('about_and_data'), style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          l10n.t('profile_device_only'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  l10n.t('profile_privacy_note'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _genderLabel(AppLocalizations l10n, String gender) {
    switch (gender) {
      case 'male':
        return l10n.t('gender_male');
      case 'other':
        return l10n.t('gender_other');
      default:
        return l10n.t('gender_female');
    }
  }

  String _languageLabel(String code) {
    const names = {
      'en': 'English',
      'hi': 'हिन्दी',
      'mr': 'मराठी',
      'bn': 'বাংলা',
      'gu': 'ગુજરાતી',
      'ta': 'தமிழ்',
    };
    return names[code] ?? code;
  }
}

class _ProfileHeader extends StatelessWidget {
  final ProfileProvider profileProvider;
  final VoidCallback onEdit;

  const _ProfileHeader({
    required this.profileProvider,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = profileProvider.profile!;
    final percent = profileProvider.isComplete ? 100 : 0;
    final initial = profile.firstName.trim().isEmpty
        ? 'H'
        : profile.firstName.trim().substring(0, 1).toUpperCase();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.tealSoft,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.tealDark,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        profile.phone.isEmpty ? l10n.t('phone_not_set') : profile.phone,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppStatusChip(
                  label: l10n.t('device_only'),
                  color: AppColors.tealDark,
                  background: AppColors.tealSoft,
                  icon: Icons.smartphone_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: percent / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFF0F5F3),
                      valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$percent% ${l10n.t('complete')}',
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.t('edit_profile')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.slate),
          const SizedBox(width: 10),
          SizedBox(
            width: 126,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w500,
                fontSize: 13.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
