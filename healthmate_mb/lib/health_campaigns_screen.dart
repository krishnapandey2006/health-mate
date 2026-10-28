import 'package:flutter/material.dart';

import 'app/theme.dart';
import 'l10n/app_localizations.dart';
import 'models/health_campaign.dart';
import 'services/campaign_service.dart';
import 'widgets/app_widgets.dart';

class HealthCampaignsScreen extends StatefulWidget {
  const HealthCampaignsScreen({super.key});

  @override
  State<HealthCampaignsScreen> createState() => _HealthCampaignsScreenState();
}

class _HealthCampaignsScreenState extends State<HealthCampaignsScreen> {
  final _campaignService = CampaignService();
  final _searchController = TextEditingController();

  CampaignLoadResult? _result;
  List<CampaignView> _views = const [];
  bool _loading = true;
  bool _showPast = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (mounted) setState(() => _loading = true);
    final result = await _campaignService.load(forceRefresh: refresh);
    if (!mounted) return;
    setState(() {
      _result = result;
      _loading = false;
      _views = _showPast
          ? _campaignService.past(DateTime.now(), cityQuery: _query)
          : _campaignService.upcoming(DateTime.now(), cityQuery: _query);
    });
  }

  void _applyFilter({bool? showPast}) {
    setState(() {
      if (showPast != null) _showPast = showPast;
      _views = _showPast
          ? _campaignService.past(DateTime.now(), cityQuery: _query)
          : _campaignService.upcoming(DateTime.now(), cityQuery: _query);
    });
  }

  void _showDetails(CampaignView view) {
    final l10n = AppLocalizations.of(context);
    final campaign = view.campaign;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        campaign.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    AppStatusChip(
                      label: view.status == CampaignStatus.ongoing
                          ? l10n.t('ongoing')
                          : view.status == CampaignStatus.upcoming
                              ? l10n.t('upcoming')
                              : l10n.t('past'),
                      color: view.status == CampaignStatus.ongoing
                          ? AppColors.success
                          : view.status == CampaignStatus.upcoming
                              ? AppColors.tealDark
                              : AppColors.slate,
                      background: view.status == CampaignStatus.ongoing
                          ? AppColors.successSoft
                          : view.status == CampaignStatus.upcoming
                              ? AppColors.tealSoft
                              : const Color(0xFFF0F5F3),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formatDateRange(view.start, view.end),
                  style: const TextStyle(
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                _DetailRow(icon: Icons.campaign_outlined, label: l10n.t('organizer'), value: campaign.organizer),
                _DetailRow(
                  icon: Icons.location_on_outlined,
                  label: l10n.t('venue'),
                  value: campaign.venue.isEmpty ? campaign.city : campaign.venue,
                ),
                if (campaign.city.isNotEmpty)
                  _DetailRow(icon: Icons.location_city_outlined, label: l10n.t('city'), value: campaign.city),
                if (campaign.timeNote != null && campaign.timeNote!.isNotEmpty)
                  _DetailRow(icon: Icons.schedule_outlined, label: l10n.t('time'), value: campaign.timeNote!),
                const SizedBox(height: 8),
                Text(campaign.description, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 18),
                AppInfoBanner(
                  icon: Icons.verified_outlined,
                  text: l10n.t('campaign_source_note'),
                  color: AppColors.tealDark,
                  background: AppColors.tealSoft,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => openExternalUrl(
                    context,
                    campaign.sourceUrl,
                    failureMessage: l10n.t('campaign_source_failed'),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text('${l10n.t('official_source')} · ${campaign.sourceName}'),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.t('campaign_no_registration'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final result = _result;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('health_campaigns')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: () => _load(refresh: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 920,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l10n.t('campaigns_intro'), style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: l10n.t('search_city_or_campaign'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: l10n.t('clear'),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                  _applyFilter();
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (value) {
                        setState(() => _query = value.trim());
                        _applyFilter();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: Text(l10n.t('upcoming_and_ongoing')),
                          selected: !_showPast,
                          onSelected: (_) => _applyFilter(showPast: false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(l10n.t('past')),
                          selected: _showPast,
                          onSelected: (_) => _applyFilter(showPast: true),
                        ),
                      ],
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 12),
                      AppInfoBanner(
                        icon: Icons.verified_outlined,
                        text:
                            '${result.source} · ${l10n.t('last_updated')} ${formatDateTime(result.lastUpdated)}',
                        color: AppColors.tealDark,
                        background: AppColors.tealSoft,
                      ),
                      if (result.warning != null) ...[
                        const SizedBox(height: 8),
                        AppInfoBanner(
                          icon: Icons.cloud_off_outlined,
                          text: result.warning!,
                          color: AppColors.warning,
                          background: AppColors.warningSoft,
                        ),
                      ],
                      if (result.error != null) ...[
                        const SizedBox(height: 8),
                        AppInfoBanner(
                          icon: Icons.error_outline_rounded,
                          text: result.error!,
                          color: AppColors.danger,
                          background: AppColors.dangerSoft,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: Column(
                    children: [
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                    ],
                  ),
                ),
              )
            else if (_views.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: _showPast ? Icons.history_rounded : Icons.event_busy_outlined,
                  title: _showPast ? l10n.t('no_past_campaigns') : l10n.t('no_upcoming_campaigns'),
                  message: _query.isEmpty
                      ? l10n.t('no_campaigns_body')
                      : l10n.t('no_campaigns_for_location'),
                  actionLabel: l10n.t('retry'),
                  onAction: () => _load(refresh: true),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: Column(
                    children: [
                      for (var i = 0; i < _views.length; i++) ...[
                        _CampaignCard(view: _views[i], onTap: () => _showDetails(_views[i])),
                        if (i != _views.length - 1) const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                      AppInfoBanner(
                        icon: Icons.info_outline_rounded,
                        text: l10n.t('campaigns_disclaimer'),
                        color: AppColors.slate,
                        background: const Color(0xFFF0F5F3),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => openExternalUrl(context, 'https://www.who.int/campaigns'),
                            child: Text(l10n.t('who_campaigns')),
                          ),
                          OutlinedButton(
                            onPressed: () => openExternalUrl(context, 'https://nhm.gov.in/'),
                            child: Text(l10n.t('nhm_india')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final CampaignView view;
  final VoidCallback onTap;

  const _CampaignCard({required this.view, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final campaign = view.campaign;
    final start = view.start;
    final statusColor = view.status == CampaignStatus.ongoing
        ? AppColors.success
        : view.status == CampaignStatus.upcoming
            ? AppColors.teal
            : AppColors.muted;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      '${start.day}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _monthShort(start.month),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.title,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDateRange(view.start, view.end),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${campaign.organizer} · ${campaign.venue}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppStatusChip(
                          label: view.status == CampaignStatus.ongoing
                              ? l10n.t('ongoing')
                              : view.status == CampaignStatus.upcoming
                                  ? l10n.t('upcoming')
                                  : l10n.t('past'),
                          color: statusColor,
                          background: statusColor.withValues(alpha: 0.10),
                        ),
                        AppStatusChip(
                          label: campaign.sourceName,
                          color: AppColors.slate,
                          background: const Color(0xFFF0F5F3),
                          icon: Icons.verified_outlined,
                        ),
                      ],
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

  String _monthShort(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.slate),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.navy, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
