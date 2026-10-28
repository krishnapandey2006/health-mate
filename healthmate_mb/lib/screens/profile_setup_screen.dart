import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../models/user_profile.dart';
import '../services/app_settings_provider.dart';
import '../services/profile_provider.dart';
import '../widgets/app_widgets.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEdit;

  /// Set this when the setup screen was pushed from another page and should
  /// return there after a successful save instead of waiting for AppGate.
  final bool popOnSave;

  const ProfileSetupScreen({
    super.key,
    this.isEdit = false,
    this.popOnSave = false,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();

  DateTime? _dateOfBirth;
  String _gender = 'female';
  String _state = '';
  bool _voiceGuidance = true;
  bool _saving = false;
  String? _saveError;

  static const _states = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Andaman and Nicobar Islands',
    'Chandigarh',
    'Dadra and Nagar Haveli and Daman and Diu',
    'Delhi',
    'Jammu and Kashmir',
    'Ladakh',
    'Lakshadweep',
    'Puducherry',
  ];

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    final settings = context.read<AppSettingsProvider>();
    if (profile != null) {
      _firstNameController.text = profile.firstName;
      _lastNameController.text = profile.lastName;
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _dateOfBirth = profile.dateOfBirth;
      if (profile.dateOfBirth != null) {
        _dobController.text = formatDateTime(profile.dateOfBirth!);
      }
      _gender = profile.gender;
      _state = profile.state;
      _voiceGuidance = profile.voiceGuidance;
    } else {
      _voiceGuidance = settings.voiceGuidance;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 120, now.month, now.day);
    var initial = _dateOfBirth ?? DateTime(now.year - 30, now.month, now.day);
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(now)) initial = now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: now,
      helpText: AppLocalizations.of(context).t('select_date_of_birth'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _dateOfBirth = picked;
      _dobController.text = formatDateTime(picked);
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() => _saveError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_saving) return;

    setState(() => _saving = true);
    final provider = context.read<ProfileProvider>();
    final settings = context.read<AppSettingsProvider>();
    final language = context.read<LanguageProvider>();
    final current = provider.profile;

    final profile = UserProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      dateOfBirth: _dateOfBirth,
      gender: _gender,
      state: _state,
      languageCode: language.languageCode,
      needsAssistance: settings.readingAssistance,
      voiceGuidance: _voiceGuidance,
      createdAt: current?.createdAt,
    );

    final saved = await provider.save(profile);
    if (!saved) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = AppLocalizations.of(context).t('profile_save_failed');
      });
      return;
    }

    await settings.setVoiceGuidance(_voiceGuidance);
    if (!mounted) return;
    setState(() => _saving = false);

    if (widget.isEdit || widget.popOnSave) {
      Navigator.of(context).pop();
      showAppSnackBar(context, AppLocalizations.of(context).t('profile_saved'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = context.watch<ProfileProvider>();

    final form = Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.storageError != null) ...[
            AppInfoBanner(
              icon: Icons.sd_card_alert_outlined,
              text: provider.storageError!,
              color: AppColors.warning,
              background: AppColors.warningSoft,
            ),
            const SizedBox(height: 14),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.t('first_name')),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return l10n.t('name_required');
                    if (text.length < 2) return l10n.t('name_too_short');
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(labelText: l10n.t('last_name')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\- ]')),
              LengthLimitingTextInputFormatter(15),
            ],
            decoration: InputDecoration(
              labelText: l10n.t('mobile_number'),
              prefixIcon: const Icon(Icons.phone_outlined),
            ),
            validator: (value) {
              final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return l10n.t('phone_required');
              if (digits.length < 10 || digits.length > 13) {
                return l10n.t('phone_invalid');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '${l10n.t('email')} (${l10n.t('optional')})',
              prefixIcon: const Icon(Icons.mail_outline_rounded),
            ),
            validator: (value) {
              final text = value?.trim() ?? '';
              if (text.isEmpty) return null;
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
                return l10n.t('email_invalid');
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _dobController,
            readOnly: true,
            onTap: _pickDateOfBirth,
            decoration: InputDecoration(
              labelText: l10n.t('date_of_birth'),
              prefixIcon: const Icon(Icons.cake_outlined),
              suffixIcon: const Icon(Icons.calendar_month_outlined),
            ),
            validator: (_) => _dateOfBirth == null ? l10n.t('dob_required') : null,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _gender,
            decoration: InputDecoration(
              labelText: l10n.t('gender'),
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            items: [
              DropdownMenuItem(value: 'female', child: Text(l10n.t('gender_female'))),
              DropdownMenuItem(value: 'male', child: Text(l10n.t('gender_male'))),
              DropdownMenuItem(value: 'other', child: Text(l10n.t('gender_other'))),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _gender = value);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _state.isEmpty ? null : _state,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n.t('state_region'),
              prefixIcon: const Icon(Icons.map_outlined),
            ),
            items: [
              for (final state in _states)
                DropdownMenuItem(value: state, child: Text(state)),
            ],
            onChanged: (value) => setState(() => _state = value ?? ''),
            validator: (value) =>
                value == null || value.isEmpty ? l10n.t('state_required') : null,
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up_outlined, color: AppColors.teal),
            title: Text(l10n.t('voice_guidance')),
            subtitle: Text(l10n.t('voice_guidance_body')),
            value: _voiceGuidance,
            onChanged: (value) => setState(() => _voiceGuidance = value),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.t('local_profile_note'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_saveError != null) ...[
            const SizedBox(height: 10),
            Text(
              _saveError!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isEdit ? l10n.t('save_changes') : l10n.t('create_local_profile')),
          ),
          if (!widget.isEdit && !widget.popOnSave) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _saving ? null : () => context.read<ProfileProvider>().skipSetup(),
              child: Text(l10n.t('explore_without_profile')),
            ),
          ],
        ],
      ),
    );

    if (widget.isEdit) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.t('edit_profile'))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: ResponsiveBody(
            maxWidth: 620,
            padding: EdgeInsets.zero,
            child: form,
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: AppLogo(size: 48, showWordmark: true),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    l10n.t('one_time_profile_title'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 30,
                          height: 1.15,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.t('one_time_profile_body'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.slate,
                          height: 1.55,
                        ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                    ),
                    child: form,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.t('local_storage_short'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
