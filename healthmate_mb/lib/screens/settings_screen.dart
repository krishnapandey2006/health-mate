import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../language_provider.dart';
import '../l10n/app_localizations.dart';
import '../services/app_settings_provider.dart';
import '../services/profile_provider.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';
import 'profile_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _languages = [
    ('en', 'English'),
    ('hi', 'हिन्दी'),
    ('mr', 'मराठी'),
    ('bn', 'বাংলা'),
    ('gu', 'ગુજરાતી'),
    ('ta', 'தமிழ்'),
  ];

  Future<void> _changeLanguage(BuildContext context, String code) async {
    final l10n = AppLocalizations.of(context);
    final language = context.read<LanguageProvider>();
    final profileProvider = context.read<ProfileProvider>();
    await language.setLanguage(code);
    final profile = profileProvider.profile;
    if (profile != null && profile.languageCode != code) {
      final saved =
          await profileProvider.save(profile.copyWith(languageCode: code));
      if (!context.mounted) return;
      if (!saved) {
        showAppSnackBar(context, l10n.t('auth_generic_error'), isError: true);
      }
    }
  }

  Future<void> _editEmergencyNumber(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<AppSettingsProvider>();
    final controller = TextEditingController(text: settings.emergencyNumber);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('emergency_number')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.t('emergency_number'),
            hintText: '112',
            prefixIcon: const Icon(Icons.call_outlined),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.t('cancel'))),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.t('save')),
          ),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    final saved = await settings.setEmergencyNumber(value);
    if (!context.mounted) return;
    showAppSnackBar(
      context,
      saved ? l10n.t('emergency_number_saved') : l10n.t('emergency_number_invalid'),
      isError: !saved,
    );
  }

  Future<void> _callEmergency(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final number = context.read<AppSettingsProvider>().emergencyNumber;
    try {
      await SOSService.openDialer(number);
    } catch (_) {
      if (context.mounted) {
        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
      }
    }
  }

  void _showSources(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.t('data_sources'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(l10n.t('data_sources_body'), style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              _SourceTile(
                title: 'WHO',
                subtitle: l10n.t('source_who'),
                onTap: () => openExternalUrl(context, 'https://www.who.int/'),
              ),
              _SourceTile(
                title: l10n.t('source_mohfw_title'),
                subtitle: l10n.t('source_mohfw'),
                onTap: () => openExternalUrl(context, 'https://mohfw.gov.in/'),
              ),
              _SourceTile(
                title: 'NHM',
                subtitle: l10n.t('source_nhm'),
                onTap: () => openExternalUrl(context, 'https://nhm.gov.in/'),
              ),
              _SourceTile(
                title: 'OpenStreetMap',
                subtitle: l10n.t('source_osm'),
                onTap: () => openExternalUrl(context, 'https://www.openstreetmap.org/'),
              ),
              _SourceTile(
                title: l10n.t('source_news_title'),
                subtitle: l10n.t('source_news'),
                onTap: () => openExternalUrl(context, 'https://news.google.com/'),
              ),
              const SizedBox(height: 10),
              AppInfoBanner(
                icon: Icons.info_outline_rounded,
                text: l10n.t('sources_disclaimer'),
                color: AppColors.slate,
                background: const Color(0xFFF0F5F3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = context.watch<AppSettingsProvider>();
    final language = context.watch<LanguageProvider>();
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 820,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.tealSoft,
                    child: Text(
                      profile?.firstName.trim().isNotEmpty == true
                          ? profile!.firstName.trim().substring(0, 1).toUpperCase()
                          : 'H',
                      style: const TextStyle(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(profile?.displayName ?? l10n.t('profile')),
                  subtitle: Text(l10n.t('device_only')),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProfileSetupScreen(isEdit: true)),
                      );
                    },
                    child: Text(l10n.t('manage')),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: l10n.t('language_and_region')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.t('app_language_body'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _languages.any((item) => item.$1 == language.languageCode)
                            ? language.languageCode
                            : 'en',
                        decoration: InputDecoration(
                          labelText: l10n.t('app_language'),
                          prefixIcon: const Icon(Icons.translate_rounded),
                        ),
                        items: [
                          for (final item in _languages)
                            DropdownMenuItem(value: item.$1, child: Text(item.$2)),
                        ],
                        onChanged: (value) {
                          if (value != null) _changeLanguage(context, value);
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        l10n.t('language_change_note'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: l10n.t('accessibility')),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.text_fields_rounded, color: AppColors.teal),
                      title: Text(l10n.t('reading_assistance')),
                      subtitle: Text(l10n.t('reading_assistance_body')),
                      value: settings.readingAssistance,
                      onChanged: settings.setReadingAssistance,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.format_size_rounded, color: AppColors.teal, size: 22),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  l10n.t('text_size'),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.navy,
                                      ),
                                ),
                              ),
                              Text(
                                '${(settings.textScale * 100).round()}%',
                                style: const TextStyle(
                                  color: AppColors.tealDark,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: settings.textScale.clamp(1.0, 1.5),
                            min: 1.0,
                            max: 1.5,
                            divisions: 5,
                            label: '${(settings.textScale * 100).round()}%',
                            onChanged: settings.setTextScale,
                          ),
                          Text(
                            l10n.t('text_size_preview'),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 15 * settings.textScale,
                                ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.volume_up_outlined, color: AppColors.teal),
                      title: Text(l10n.t('voice_guidance')),
                      subtitle: Text(l10n.t('voice_guidance_body')),
                      value: settings.voiceGuidance,
                      onChanged: settings.setVoiceGuidance,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: l10n.t('notifications')),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.notifications_outlined, color: AppColors.teal),
                      title: Text(l10n.t('notifications')),
                      subtitle: Text(l10n.t('notifications_body')),
                      value: settings.notificationsEnabled,
                      onChanged: settings.setNotificationsEnabled,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: AppInfoBanner(
                        icon: Icons.info_outline_rounded,
                        text: l10n.t('notifications_unconfigured_note'),
                        color: AppColors.slate,
                        background: const Color(0xFFF0F5F3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: l10n.t('emergency')),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.call_outlined, color: AppColors.danger),
                  title: Text(l10n.t('emergency_number')),
                  subtitle: Text(settings.emergencyNumber),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: l10n.t('edit'),
                        onPressed: () => _editEmergencyNumber(context),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: l10n.t('call'),
                        onPressed: () => _callEmergency(context),
                        icon: const Icon(Icons.phone_outlined, color: AppColors.danger),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionLabel(label: l10n.t('about_and_data')),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dataset_outlined, color: AppColors.teal),
                      title: Text(l10n.t('data_sources')),
                      subtitle: Text(l10n.t('data_sources_short')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _showSources(context),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.teal),
                      title: Text(l10n.t('privacy')),
                      subtitle: Text(l10n.t('privacy_body')),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l10n.t('privacy')),
                            content: Text(l10n.t('privacy_detail')),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: Text(l10n.t('close')),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded, color: AppColors.teal),
                      title: Text(l10n.t('app_version')),
                      subtitle: const Text('HealthMate 1.0.0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.t('settings_disclaimer'),
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

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.slate,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.public_rounded, color: AppColors.teal),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: const Icon(Icons.open_in_new_rounded, size: 18, color: AppColors.muted),
      onTap: onTap,
    );
  }
}
