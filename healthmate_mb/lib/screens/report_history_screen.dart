import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/health_report.dart';
import '../services/report_service.dart';
import '../widgets/app_widgets.dart';

class ReportHistoryScreen extends StatefulWidget {
  const ReportHistoryScreen({super.key});

  @override
  State<ReportHistoryScreen> createState() => _ReportHistoryScreenState();
}

class _ReportHistoryScreenState extends State<ReportHistoryScreen> {
  final _reportService = ReportService();
  List<HealthReport> _reports = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final reports = await _reportService.loadHistory();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppLocalizations.of(context).t('report_history_error');
      });
    }
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

  Future<void> _copyReport(HealthReport report) async {
    final l10n = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: report.toShareText()));
    if (!mounted) return;
    showAppSnackBar(context, l10n.t('report_copied'));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('report_history')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5))
          : _error != null
              ? AppErrorState(
                  title: l10n.t('report_history_unavailable'),
                  message: _error!,
                  onRetry: _load,
                )
              : _reports.isEmpty
                  ? AppEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: l10n.t('no_reports_title'),
                      message: l10n.t('no_reports_body'),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 860),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.t('report_history_local_note'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(height: 1.5),
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      border: Border.all(color: AppColors.border),
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.lg),
                                    ),
                                    child: Column(
                                      children: [
                                        for (var i = 0;
                                            i < _reports.length;
                                            i++) ...[
                                          _ReportRow(
                                            report: _reports[i],
                                            categoryLabel: _categoryLabel(
                                              l10n,
                                              _reports[i].category,
                                            ),
                                            onTap: () => _showDetails(_reports[i]),
                                          ),
                                          if (i != _reports.length - 1)
                                            const Divider(height: 1),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }

  void _showDetails(HealthReport report) {
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
              Text(
                report.type == ReportType.personalConcern
                    ? l10n.t('report_personal_title')
                    : l10n.t('report_feedback_title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                '${l10n.t('report_reference')}: ${report.reference}',
                style: const TextStyle(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatDateTime(report.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              Text(
                _categoryLabel(l10n, report.category),
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(report.description, style: Theme.of(context).textTheme.bodyMedium),
              if (report.area.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        report.area,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              Text(
                l10n.t('report_saved_local_body'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _copyReport(report),
                icon: const Icon(Icons.copy_rounded),
                label: Text(l10n.t('report_copy')),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.t('close')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final HealthReport report;
  final String categoryLabel;
  final VoidCallback onTap;

  const _ReportRow({
    required this.report,
    required this.categoryLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    categoryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy,
                    ),
                  ),
                ),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.t('report_status_saved'),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  report.reference,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  formatDateTime(report.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
