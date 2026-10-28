import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';
import '../models/vaccination_record.dart';
import '../services/profile_provider.dart';
import '../services/vaccine_service.dart';
import '../widgets/app_widgets.dart';
import 'profile_setup_screen.dart';

class VaccineScreen extends StatefulWidget {
  const VaccineScreen({super.key});

  @override
  State<VaccineScreen> createState() => _VaccineScreenState();
}

enum _VaccineFilter { all, recorded, upcoming, noRecord }

class _VaccineScreenState extends State<VaccineScreen> {
  final _repository = VaccinationRepository();
  List<VaccinationRecord> _records = const [];
  bool _loading = true;
  _VaccineFilter _filter = _VaccineFilter.all;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final records = await _repository.load();
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).t('vaccine_load_error');
      });
    }
  }

  Future<void> _openRecordSheet(
    VaccineScheduleItem item,
    VaccinationRecord? existing,
  ) async {
    final l10n = AppLocalizations.of(context);
    final profile = context.read<ProfileProvider>().profile;
    final now = DateTime.now();
    final firstDate = profile?.dateOfBirth ?? DateTime(1900);
    final picked = await showDatePicker(
      context: context,
      initialDate: existing?.date ?? now,
      firstDate: firstDate.isAfter(now) ? now : firstDate,
      lastDate: now,
      helpText: l10n.t('vaccine_record_date'),
    );
    if (picked == null || !mounted) return;

    final notesController = TextEditingController(text: existing?.notes ?? '');
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(item.ageLabel, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 14),
                TextFormField(
                  controller: notesController,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: l10n.t('vaccine_notes_optional'),
                    hintText: l10n.t('vaccine_notes_hint'),
                  ),
                ),
                const SizedBox(height: 6),
                AppInfoBanner(
                  icon: Icons.info_outline_rounded,
                  text: l10n.t('vaccine_record_note'),
                  color: AppColors.slate,
                  background: const Color(0xFFF0F5F3),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.t('save')),
                ),
                if (existing != null) ...[
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n.t('remove_record'),
                      style: const TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    final notes = notesController.text.trim();
    notesController.dispose();

    if (confirmed == false) {
      await _deleteRecord(item);
      return;
    }
    if (confirmed != true) return;

    final record = VaccinationRecord(
      vaccineId: item.id,
      date: picked,
      notes: notes,
    );
    final saved = await _repository.save(record);
    if (!mounted) return;
    if (!saved) {
      showAppSnackBar(context, l10n.t('vaccine_save_failed'), isError: true);
      return;
    }
    await _load();
    if (!mounted) return;
    showAppSnackBar(context, l10n.t('vaccine_saved_device'));
  }

  Future<void> _deleteRecord(VaccineScheduleItem item) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.t('remove_record')),
        content: Text(l10n.t('remove_record_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('remove')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final removed = await _repository.delete(item.id);
    if (!mounted) return;
    if (!removed) {
      showAppSnackBar(context, l10n.t('vaccine_save_failed'), isError: true);
      return;
    }
    await _load();
    if (mounted) showAppSnackBar(context, l10n.t('record_removed'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = context.watch<ProfileProvider>().profile;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('vaccines')),
        actions: [
          IconButton(
            tooltip: l10n.t('vaccine_source'),
            onPressed: () => openExternalUrl(
              context,
              VaccineService.sourceUrl,
              failureMessage: l10n.t('vaccine_source_failed'),
            ),
            icon: const Icon(Icons.menu_book_outlined),
          ),
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 880,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (profile == null)
                      AppInfoBanner(
                        icon: Icons.person_outline_rounded,
                        text: l10n.t('vaccine_profile_required_body'),
                        color: AppColors.warning,
                        background: AppColors.warningSoft,
                        trailing: TextButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProfileSetupScreen(popOnSave: true),
                              ),
                            );
                            if (mounted) _load();
                          },
                          child: Text(l10n.t('create_profile')),
                        ),
                      )
                    else if (profile.dateOfBirth == null)
                      AppInfoBanner(
                        icon: Icons.cake_outlined,
                        text: l10n.t('vaccine_dob_missing'),
                        color: AppColors.warning,
                        background: AppColors.warningSoft,
                        trailing: TextButton(
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProfileSetupScreen(isEdit: true),
                              ),
                            );
                            if (mounted) _load();
                          },
                          child: Text(l10n.t('add_dob')),
                        ),
                      )
                    else
                      _ProfileSummary(profile: profile),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AppInfoBanner(
                        icon: Icons.error_outline_rounded,
                        text: _error!,
                        color: AppColors.danger,
                        background: AppColors.dangerSoft,
                        trailing: TextButton(
                          onPressed: _load,
                          child: Text(l10n.t('retry')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    AppInfoBanner(
                      icon: Icons.verified_outlined,
                      text: l10n.t('vaccine_source_note'),
                      color: AppColors.tealDark,
                      background: AppColors.tealSoft,
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 880,
                  child: _buildContent(l10n, profile),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n, UserProfile? profile) {
    final recommendations = profile == null
        ? VaccineService.recommendationsWithoutAge(_records)
        : VaccineService.recommendationsFor(profile, _records);
    final recorded = recommendations
        .where((item) => item.status == VaccineStatus.recorded)
        .toList();
    final upcoming = recommendations
        .where((item) => item.status == VaccineStatus.upcoming)
        .toList();
    final noRecord = recommendations
        .where((item) => item.status == VaccineStatus.noRecord)
        .toList();
    final reference = recommendations
        .where((item) => item.status == VaccineStatus.notApplicable)
        .toList();

    final relevant = switch (_filter) {
      // "All" is the whole schedule. For an adult most entries are reference
      // information, and listing only the personal subset left the page empty.
      _VaccineFilter.all => [...recorded, ...upcoming, ...noRecord, ...reference],
      _VaccineFilter.recorded => recorded,
      _VaccineFilter.upcoming => upcoming,
      _VaccineFilter.noRecord => noRecord,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _VaccineSummary(
          recorded: recorded.length,
          upcoming: upcoming.length,
          noRecord: noRecord.length,
          filter: _filter,
          onFilter: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 14),
        if (relevant.isEmpty &&
            !(_filter == _VaccineFilter.all && reference.isNotEmpty))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: AppEmptyState(
              icon: Icons.vaccines_outlined,
              title: l10n.t('vaccine_no_filter_results'),
              message: l10n.t('vaccine_no_filter_results_body'),
            ),
          )
        else if (relevant.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppRadii.lg),
            ),
            child: Column(
              children: [
                for (var i = 0; i < relevant.length; i++) ...[
                  _VaccineRow(
                    recommendation: relevant[i],
                    onRecord: () => _openRecordSheet(
                      relevant[i].item,
                      relevant[i].record,
                    ),
                    onDelete: relevant[i].record == null
                        ? null
                        : () => _deleteRecord(relevant[i].item),
                  ),
                  if (i != relevant.length - 1) const Divider(height: 1),
                ],
              ],
            ),
          ),
        if (reference.isNotEmpty && _filter != _VaccineFilter.all) ...[
          const SizedBox(height: 18),
          _ReferenceSection(
            recommendations: reference,
            onRecord: (item) => _openRecordSheet(item, null),
          ),
        ],
        const SizedBox(height: 18),
        AppInfoBanner(
          icon: Icons.info_outline_rounded,
          text: l10n.t('vaccine_disclaimer'),
          color: AppColors.slate,
          background: const Color(0xFFF0F5F3),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openExternalUrl(context, VaccineService.sourceUrl),
          icon: const Icon(Icons.open_in_new_rounded),
          label: Text(l10n.t('vaccine_source')),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final UserProfile profile;

  const _ProfileSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final age = profile.age;
    final months = profile.ageInMonths;
    final ageText = months == null
        ? l10n.t('vaccine_age_unknown')
        : months < 24
            ? l10n.t('vaccine_age_months').replaceAll('{months}', '$months')
            : l10n.t('vaccine_age_years').replaceAll('{years}', '$age');
    return Row(
      children: [
        const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${profile.displayName} · $ageText',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _VaccineSummary extends StatelessWidget {
  final int recorded;
  final int upcoming;
  final int noRecord;
  final _VaccineFilter filter;
  final ValueChanged<_VaccineFilter> onFilter;

  const _VaccineSummary({
    required this.recorded,
    required this.upcoming,
    required this.noRecord,
    required this.filter,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryItem(
                  value: '$recorded',
                  label: l10n.t('vaccine_recorded'),
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  value: '$upcoming',
                  label: l10n.t('vaccine_upcoming'),
                  color: AppColors.tealDark,
                ),
              ),
              Expanded(
                child: _SummaryItem(
                  value: '$noRecord',
                  label: l10n.t('vaccine_no_record'),
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const Divider(height: 22),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in const [
                  (_VaccineFilter.all, 'all'),
                  (_VaccineFilter.recorded, 'vaccine_recorded'),
                  (_VaccineFilter.upcoming, 'vaccine_upcoming'),
                  (_VaccineFilter.noRecord, 'vaccine_no_record'),
                ]) ...[
                  ChoiceChip(
                    label: Text(l10n.t(item.$2)),
                    selected: filter == item.$1,
                    onSelected: (_) => onFilter(item.$1),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
      ],
    );
  }
}

class _VaccineRow extends StatelessWidget {
  final VaccineRecommendation recommendation;
  final VoidCallback onRecord;
  final VoidCallback? onDelete;

  const _VaccineRow({
    required this.recommendation,
    required this.onRecord,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = recommendation.item;
    final status = recommendation.status;
    final recorded = status == VaccineStatus.recorded;
    final color = recorded
        ? AppColors.success
        : status == VaccineStatus.noRecord
            ? AppColors.warning
            : AppColors.tealDark;
    final icon = recorded
        ? Icons.check_circle_outline_rounded
        : status == VaccineStatus.noRecord
            ? Icons.help_outline_rounded
            : Icons.schedule_rounded;

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.ageLabel,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _statusLabel(l10n, status),
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
          ),
          if (recommendation.record != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 15,
                  color: AppColors.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${l10n.t('vaccine_recorded_on')} ${formatDateTime(recommendation.record!.date)}',
                    style: const TextStyle(
                      color: AppColors.success,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (recommendation.record!.notes.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                recommendation.record!.notes,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11.5,
                    ),
              ),
            ],
          ],
          if (status == VaccineStatus.noRecord ||
              status == VaccineStatus.upcoming) ...[
            const SizedBox(height: 5),
            Text(
              _statusExplanation(l10n, status),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    color: status == VaccineStatus.noRecord
                        ? AppColors.warning
                        : AppColors.muted,
                  ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: onRecord,
                icon: Icon(
                  recorded ? Icons.edit_outlined : Icons.add_rounded,
                  size: 17,
                ),
                label: Text(
                  recorded ? l10n.t('edit_record') : l10n.t('add_record'),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: l10n.t('remove_record'),
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferenceSection extends StatelessWidget {
  final List<VaccineRecommendation> recommendations;
  final ValueChanged<VaccineScheduleItem> onRecord;

  const _ReferenceSection({
    required this.recommendations,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: ExpansionTile(
        initiallyExpanded: true,
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: EdgeInsets.zero,
        title: Text(
          l10n.t('vaccine_reference_title'),
          style: const TextStyle(
            color: AppColors.navy,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
          ),
        ),
        subtitle: Text(
          l10n.t('vaccine_reference_body').replaceAll(
            '{count}',
            '${recommendations.length}',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
        ),
        children: [
          const Divider(height: 1),
          for (var i = 0; i < recommendations.length; i++) ...[
            _ReferenceRow(
              item: recommendations[i].item,
              onRecord: () => onRecord(recommendations[i].item),
            ),
            if (i != recommendations.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _ReferenceRow extends StatelessWidget {
  final VaccineScheduleItem item;
  final VoidCallback onRecord;

  const _ReferenceRow({required this.item, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.ageLabel} · ${item.description}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontSize: 11.5),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRecord,
            child: Text(l10n.t('add_record')),
          ),
        ],
      ),
    );
  }
}

String _statusLabel(AppLocalizations l10n, VaccineStatus status) {
  switch (status) {
    case VaccineStatus.recorded:
      return l10n.t('vaccine_recorded');
    case VaccineStatus.upcoming:
      return l10n.t('vaccine_upcoming');
    case VaccineStatus.noRecord:
      return l10n.t('vaccine_no_record');
    case VaccineStatus.notApplicable:
      return l10n.t('vaccine_general_info');
  }
}

String _statusExplanation(AppLocalizations l10n, VaccineStatus status) {
  switch (status) {
    case VaccineStatus.recorded:
      return l10n.t('vaccine_status_recorded_body');
    case VaccineStatus.upcoming:
      return l10n.t('vaccine_status_upcoming_body');
    case VaccineStatus.noRecord:
      return l10n.t('vaccine_status_no_record_body');
    case VaccineStatus.notApplicable:
      return l10n.t('vaccine_status_general_body');
  }
}
