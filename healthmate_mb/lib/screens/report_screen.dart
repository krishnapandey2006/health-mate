import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/health_report.dart';
import '../services/report_service.dart';
import '../services/sos_service.dart';
import '../widgets/app_widgets.dart';
import 'report_history_screen.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _areaController = TextEditingController();
  final _reportService = ReportService();

  ReportType _type = ReportType.personalConcern;
  String _category = 'vaccination';
  bool _submitting = false;
  bool _locating = false;
  double? _latitude;
  double? _longitude;
  String? _locationError;

  static const _personalCategories = [
    'vaccination',
    'treatment_access',
    'unsafe_care',
    'maternal_health',
    'disease_outbreak',
    'other',
  ];

  static const _feedbackCategories = [
    'incorrect_information',
    'app_problem',
    'accessibility',
    'suggestion',
    'other',
  ];

  List<String> get _categories =>
      _type == ReportType.personalConcern
          ? _personalCategories
          : _feedbackCategories;

  @override
  void initState() {
    super.initState();
    _category = _categories.first;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  void _setType(ReportType type) {
    if (_type == type) return;
    setState(() {
      _type = type;
      _category = _categories.first;
    });
  }

  String _categoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'vaccination':
        return l10n.t('report_category_vaccination');
      case 'treatment_access':
        return l10n.t('report_category_treatment_access');
      case 'unsafe_care':
        return l10n.t('report_category_unsafe_care');
      case 'maternal_health':
        return l10n.t('report_category_maternal_health');
      case 'disease_outbreak':
        return l10n.t('report_category_outbreak');
      case 'incorrect_information':
        return l10n.t('report_category_incorrect_info');
      case 'app_problem':
        return l10n.t('report_category_app_problem');
      case 'accessibility':
        return l10n.t('report_category_accessibility');
      case 'suggestion':
        return l10n.t('report_category_suggestion');
      default:
        return l10n.t('report_category_other');
    }
  }

  Future<void> _useCurrentLocation() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _locating = false;
            _locationError = l10n.t('location_permission_denied');
          });
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      ).timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locating = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _locating = false;
          _locationError = l10n.t('location_unavailable');
        });
      }
    }
  }

  void _clearLocation() {
    setState(() {
      _latitude = null;
      _longitude = null;
      _locationError = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_submitting) return;

    final description = _descriptionController.text.trim();
    final l10n = AppLocalizations.of(context);
    final duplicate = await _reportService.isDuplicate(_category, description);
    if (!mounted) return;
    if (duplicate) {
      showAppSnackBar(context, l10n.t('report_duplicate'), isError: true);
      return;
    }

    setState(() => _submitting = true);
    ReportSaveResult result;
    try {
      result = await _reportService.submitReport(
        type: _type,
        category: _category,
        description: description,
        area: _areaController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(context, l10n.t('report_save_failed'), isError: true);
      return;
    }
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.saved) {
      showAppSnackBar(context, l10n.t('report_save_failed'), isError: true);
      return;
    }

    _descriptionController.clear();
    _areaController.clear();
    setState(() {
      _latitude = null;
      _longitude = null;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ReportConfirmation(report: result.report),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('report')),
        actions: [
          IconButton(
            tooltip: l10n.t('report_history'),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportHistoryScreen()),
              );
            },
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: ResponsiveBody(
          maxWidth: 760,
          padding: EdgeInsets.zero,
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.t('report_intro'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.slate,
                        height: 1.55,
                      ),
                ),
                const SizedBox(height: 16),
                _TypeSelector(
                  type: _type,
                  onChanged: _setType,
                  personalTitle: l10n.t('report_personal_title'),
                  personalBody: l10n.t('report_personal_body'),
                  feedbackTitle: l10n.t('report_feedback_title'),
                  feedbackBody: l10n.t('report_feedback_body'),
                ),
                if (_type == ReportType.personalConcern) ...[
                  const SizedBox(height: 12),
                  AppInfoBanner(
                    icon: Icons.emergency_outlined,
                    text: l10n.t('report_emergency_notice'),
                    color: AppColors.danger,
                    background: AppColors.dangerSoft,
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await SOSService.openDialer('112');
                        } catch (_) {
                          if (context.mounted) {
                            showAppSnackBar(
                              context,
                              l10n.t('dialer_unavailable'),
                              isError: true,
                            );
                          }
                        }
                      },
                      child: Text(l10n.t('call')),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        key: ValueKey(_type),
                        initialValue: _category,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.t('report_category'),
                          prefixIcon: const Icon(Icons.category_outlined),
                        ),
                        items: [
                          for (final category in _categories)
                            DropdownMenuItem(
                              value: category,
                              child: Text(_categoryLabel(l10n, category)),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _category = value);
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        minLines: 5,
                        maxLines: 8,
                        maxLength: 1000,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(1000),
                        ],
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: l10n.t('report_description'),
                          hintText: l10n.t('report_description_hint'),
                          alignLabelWithHint: true,
                        ),
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) {
                          return Text(
                            '$currentLength / $maxLength',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: currentLength >= (maxLength ?? 1000)
                                      ? AppColors.warning
                                      : AppColors.muted,
                                ),
                          );
                        },
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.length < 20) {
                            return l10n.t('report_description_too_short');
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _areaController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: l10n.t('report_area_optional'),
                          hintText: l10n.t('report_area_hint'),
                          prefixIcon: const Icon(Icons.location_on_outlined),
                          suffixIcon: _locating
                              ? const Padding(
                                  padding: EdgeInsets.all(14),
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: l10n.t('use_my_location'),
                                  onPressed: _useCurrentLocation,
                                  icon: Icon(
                                    _latitude == null
                                        ? Icons.my_location_rounded
                                        : Icons.check_circle_outline_rounded,
                                    color: _latitude == null
                                        ? null
                                        : AppColors.success,
                                  ),
                                ),
                        ),
                      ),
                      if (_latitude != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l10n.t('report_location_attached'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.success),
                              ),
                            ),
                            TextButton(
                              onPressed: _clearLocation,
                              child: Text(l10n.t('clear')),
                            ),
                          ],
                        ),
                      ],
                      if (_locationError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _locationError!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.warning),
                        ),
                      ],
                      const SizedBox(height: 12),
                      AppInfoBanner(
                        icon: Icons.lock_outline_rounded,
                        text: l10n.t('report_privacy_note'),
                        color: AppColors.slate,
                        background: const Color(0xFFF0F5F3),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _submitting ? null : _submit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _submitting
                              ? l10n.t('report_saving')
                              : l10n.t('report_save'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.t('report_local_only_note'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSelector extends StatelessWidget {
  final ReportType type;
  final ValueChanged<ReportType> onChanged;
  final String personalTitle;
  final String personalBody;
  final String feedbackTitle;
  final String feedbackBody;

  const _TypeSelector({
    required this.type,
    required this.onChanged,
    required this.personalTitle,
    required this.personalBody,
    required this.feedbackTitle,
    required this.feedbackBody,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      (ReportType.personalConcern, Icons.health_and_safety_outlined,
          personalTitle, personalBody),
      (ReportType.feedback, Icons.feedback_outlined, feedbackTitle, feedbackBody),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 540;
        final children = [
          for (final option in options)
            _TypeOption(
              selected: type == option.$1,
              icon: option.$2,
              title: option.$3,
              body: option.$4,
              onTap: () => onChanged(option.$1),
            ),
        ];
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              children[0],
              const SizedBox(height: 8),
              children[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: children[0]),
            const SizedBox(width: 10),
            Expanded(child: children[1]),
          ],
        );
      },
    );
  }
}

class _TypeOption extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  const _TypeOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: Material(
        color: selected ? AppColors.tealSoft : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: selected ? AppColors.teal : AppColors.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? AppColors.tealDark : AppColors.slate,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.tealDark : AppColors.navy,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        body,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: AppColors.teal,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportConfirmation extends StatelessWidget {
  final HealthReport report;

  const _ReportConfirmation({required this.report});

  Future<void> _copy(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: report.toShareText()));
    if (!context.mounted) return;
    showAppSnackBar(context, l10n.t('report_copied'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.save_outlined,
              size: 38,
              color: AppColors.tealDark,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.t('report_saved_device_title'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.t('report_saved_local_body'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F3),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tag_rounded, size: 18, color: AppColors.slate),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l10n.t('report_reference')}: ${report.reference}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _copy(context),
              icon: const Icon(Icons.copy_rounded),
              label: Text(l10n.t('report_copy')),
            ),
            const SizedBox(height: 6),
            OutlinedButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => const ReportHistoryScreen()),
                );
              },
              child: Text(l10n.t('report_view_history')),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.t('close')),
            ),
          ],
        ),
      ),
    );
  }
}
