import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../health_campaigns_screen.dart';
import '../health_news_screen.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../models/article.dart';
import '../models/health_campaign.dart';
import '../services/app_settings_provider.dart';
import '../services/campaign_service.dart';
import '../services/news_service.dart';
import '../services/profile_provider.dart';
import '../services/sos_service.dart';
import '../services/vaccine_service.dart';
import '../widgets/app_widgets.dart';
import 'book_screen.dart';
import 'nearby_screen.dart';
import 'profile_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'vaccine_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _newsService = NewsService();
  final _campaignService = CampaignService();
  final _vaccinationRepository = VaccinationRepository();

  List<Article> _articles = const [];
  List<CampaignView> _campaigns = const [];
  bool _loadingNews = true;
  bool _loadingCampaigns = true;
  String? _newsError;
  String? _campaignWarning;
  DateTime? _newsUpdatedAt;
  int _vaccinationCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadNews(), _loadCampaigns(), _loadVaccinations()]);
  }

  Future<void> _loadNews({bool refresh = false}) async {
    if (mounted) {
      setState(() {
        _loadingNews = true;
        _newsError = null;
      });
    }
    final result = await _newsService.fetchPage(
      category: 'all',
      lang: context.read<LanguageProvider>().languageCode,
      page: 1,
      limit: 4,
      forceRefresh: refresh,
    );
    if (!mounted) return;
    setState(() {
      _loadingNews = false;
      _articles = result.articles.take(3).toList();
      _newsError = result.isError && result.articles.isEmpty
          ? result.error?.message
          : result.warning;
      _newsUpdatedAt = result.lastUpdated;
    });
  }

  Future<void> _loadCampaigns({bool refresh = false}) async {
    if (mounted) setState(() => _loadingCampaigns = true);
    final result = await _campaignService.load(forceRefresh: refresh);
    if (!mounted) return;
    setState(() {
      _loadingCampaigns = false;
      _campaigns = _campaignService.upcoming(DateTime.now()).take(2).toList();
      _campaignWarning = result.error ?? result.warning;
    });
  }

  Future<void> _loadVaccinations() async {
    final records = await _vaccinationRepository.load();
    if (!mounted) return;
    setState(() => _vaccinationCount = records.length);
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  void _open(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _showEmergency() async {
    final settings = context.read<AppSettingsProvider>();
    final l10n = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: AppColors.dangerSoft,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emergency_outlined, color: AppColors.danger),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.t('emergency_help'), style: Theme.of(context).textTheme.titleLarge),
                          Text(
                            l10n.t('emergency_help_body'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                  onPressed: () async {
                    try {
                      await SOSService.openDialer(settings.emergencyNumber);
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.call_rounded),
                  label: Text('${l10n.t('call_emergency')} · ${settings.emergencyNumber}'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await SOSService.openDialer('108');
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnackBar(context, l10n.t('dialer_unavailable'), isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.local_hospital_outlined),
                  label: Text(l10n.t('call_ambulance_108')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    try {
                      await SOSService.sendSms(
                        settings.emergencyNumber,
                        l10n.t('sos_message'),
                      );
                    } catch (_) {
                      if (context.mounted) {
                        showAppSnackBar(context, l10n.t('sms_unavailable'), isError: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l10n.t('send_sos_sms')),
                ),
                const SizedBox(height: 14),
                Text(
                  l10n.t('emergency_disclaimer'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
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
    final profileProvider = context.watch<ProfileProvider>();
    final profile = profileProvider.profile;
    final firstName = profile?.firstName.trim() ?? '';
    final greeting = firstName.isEmpty ? l10n.t('welcome') : '${l10n.t('namaste')}, $firstName';
    final now = DateTime.now();
    final hour = now.hour;
    final timeGreeting = hour < 12
        ? l10n.t('good_morning')
        : hour < 17
            ? l10n.t('good_afternoon')
            : l10n.t('good_evening');

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.mintBackground,
              titleSpacing: 16,
              title: Row(
                children: [
                  const AppLogo(size: 34),
                  const SizedBox(width: 10),
                  Text(
                    'HealthMate',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: l10n.t('settings_title'),
                  onPressed: () => _open(const SettingsScreen()),
                  icon: const Icon(Icons.settings_outlined),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: () => _open(const ProfileScreen()),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.tealSoft,
                      child: Text(
                        firstName.isEmpty ? 'H' : firstName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 980,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      '$timeGreeting, $greeting',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('home_subtitle'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 26),
                    ),
                    const SizedBox(height: 18),
                    _ReadinessCard(
                      percent: profileProvider.isComplete ? 100 : 0,
                      vaccinations: _vaccinationCount,
                      onTap: () => _open(const ProfileScreen()),
                    ),
                    const SizedBox(height: 18),
                    _EmergencyStrip(onTap: _showEmergency),
                    const SizedBox(height: 24),
                    SectionHeader(
                      title: l10n.t('quick_actions'),
                      actionLabel: null,
                    ),
                    const SizedBox(height: 12),
                    _QuickActions(
                      onNearby: () => _open(const NearbyScreen()),
                      onReport: () => _open(const ReportScreen()),
                      onBook: () => _open(const BookScreen()),
                      onVaccines: () => _open(const VaccineScreen()),
                      onNews: () => _open(const HealthNewsScreen()),
                      onCampaigns: () => _open(const HealthCampaignsScreen()),
                    ),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: l10n.t('latest_health_news'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => _open(const HealthNewsScreen()),
                    ),
                    const SizedBox(height: 10),
                    _buildNewsSection(l10n),
                    const SizedBox(height: 28),
                    SectionHeader(
                      title: l10n.t('verified_campaigns'),
                      actionLabel: l10n.t('see_all'),
                      onAction: () => _open(const HealthCampaignsScreen()),
                    ),
                    const SizedBox(height: 10),
                    _buildCampaignSection(l10n),
                    const SizedBox(height: 28),
                    _ProfileStatusCard(
                      complete: profileProvider.isComplete,
                      onTap: () => _open(const ProfileScreen()),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.t('home_disclaimer'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
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

  Widget _buildNewsSection(AppLocalizations l10n) {
    if (_loadingNews) {
      return const Column(
        children: [
          ArticleSkeleton(),
          SizedBox(height: 10),
          ArticleSkeleton(),
        ],
      );
    }
    if (_articles.isEmpty) {
      return AppInfoBanner(
        icon: Icons.newspaper_outlined,
        text: _newsError ?? l10n.t('no_updates'),
        color: _newsError == null ? AppColors.slate : AppColors.warning,
        background: _newsError == null ? const Color(0xFFF0F5F3) : AppColors.warningSoft,
        trailing: TextButton(
          onPressed: () => _loadNews(refresh: true),
          child: Text(l10n.t('retry')),
        ),
      );
    }

    return Column(
      children: [
        if (_newsError != null) ...[
          AppInfoBanner(
            icon: Icons.info_outline_rounded,
            text: _newsError!,
            color: AppColors.warning,
            background: AppColors.warningSoft,
          ),
          const SizedBox(height: 10),
        ],
        for (var i = 0; i < _articles.length; i++) ...[
          _CompactArticleCard(
            article: _articles[i],
            onTap: () => _open(HealthNewsScreen(initialArticle: _articles[i])),
          ),
          if (i != _articles.length - 1) const SizedBox(height: 10),
        ],
        if (_newsUpdatedAt != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${l10n.t('last_updated')} ${formatShortDate(_newsUpdatedAt!, l10n)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCampaignSection(AppLocalizations l10n) {
    if (_loadingCampaigns) {
      return const ArticleSkeleton();
    }
    if (_campaigns.isEmpty) {
      return AppInfoBanner(
        icon: Icons.event_busy_outlined,
        text: _campaignWarning ?? l10n.t('no_upcoming_campaigns'),
        color: AppColors.slate,
        background: const Color(0xFFF0F5F3),
        trailing: TextButton(
          onPressed: () => _loadCampaigns(refresh: true),
          child: Text(l10n.t('retry')),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _campaigns.length; i++) ...[
          _CampaignPreviewCard(
            view: _campaigns[i],
            onTap: () => _open(const HealthCampaignsScreen()),
          ),
          if (i != _campaigns.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ReadinessCard extends StatelessWidget {
  final int percent;
  final int vaccinations;
  final VoidCallback onTap;

  const _ReadinessCard({
    required this.percent,
    required this.vaccinations,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0B6E63), Color(0xFF0F9D8A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              SizedBox(
                width: 78,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 7,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$percent%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('readiness_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.t('readiness_body'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MiniStat(
                          icon: Icons.vaccines_outlined,
                          label: l10n.t('records_saved'),
                          value: '$vaccinations',
                        ),
                        const SizedBox(width: 16),
                        _MiniStat(
                          icon: Icons.arrow_forward_rounded,
                          label: l10n.t('view_profile'),
                          value: '',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
        const SizedBox(width: 5),
        Text(
          value.isEmpty ? label : '$value $label',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmergencyStrip extends StatelessWidget {
  final VoidCallback onTap;

  const _EmergencyStrip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.dangerSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.14)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.emergency_outlined, color: AppColors.danger, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('emergency_help'),
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      l10n.t('emergency_help_short'),
                      style: const TextStyle(color: AppColors.danger, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.danger),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onNearby;
  final VoidCallback onReport;
  final VoidCallback onBook;
  final VoidCallback onVaccines;
  final VoidCallback onNews;
  final VoidCallback onCampaigns;

  const _QuickActions({
    required this.onNearby,
    required this.onReport,
    required this.onBook,
    required this.onVaccines,
    required this.onNews,
    required this.onCampaigns,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final actions = [
      (Icons.near_me_outlined, l10n.t('nearby'), AppColors.teal, onNearby),
      (Icons.report_problem_outlined, l10n.t('report'), const Color(0xFFB54708), onReport),
      (Icons.calendar_month_outlined, l10n.t('appointments'), const Color(0xFF175CD3), onBook),
      (Icons.vaccines_outlined, l10n.t('vaccines'), const Color(0xFF6941C6), onVaccines),
      (Icons.newspaper_outlined, l10n.t('news'), const Color(0xFF0E7090), onNews),
      (Icons.campaign_outlined, l10n.t('campaigns'), const Color(0xFF067647), onCampaigns),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 6 : 3;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              SizedBox(
                width: width,
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: InkWell(
                    onTap: action.$4,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: action.$3.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(action.$1, color: action.$3, size: 20),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            action.$2,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CompactArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;

  const _CompactArticleCard({required this.article, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: article.thumbnail == null
                      ? Container(
                          color: AppColors.tealSoft,
                          child: const Icon(Icons.health_and_safety_outlined, color: AppColors.teal),
                        )
                      : Image.network(
                          article.thumbnail!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.tealSoft,
                            child: const Icon(Icons.health_and_safety_outlined, color: AppColors.teal),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        height: 1.3,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            article.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.tealDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '· ${formatShortDate(article.publishedDate, l10n)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CampaignPreviewCard extends StatelessWidget {
  final CampaignView view;
  final VoidCallback onTap;

  const _CampaignPreviewCard({required this.view, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ongoing = view.status == CampaignStatus.ongoing;
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.campaign_outlined, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            view.campaign.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.navy,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppStatusChip(
                          label: ongoing ? l10n.t('ongoing') : l10n.t('upcoming'),
                          color: ongoing ? AppColors.success : AppColors.tealDark,
                          background: ongoing ? AppColors.successSoft : AppColors.tealSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatDateRange(view.start, view.end),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${view.campaign.organizer} · ${view.campaign.sourceName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileStatusCard extends StatelessWidget {
  final bool complete;
  final VoidCallback onTap;

  const _ProfileStatusCard({
    required this.complete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.tealSoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  complete ? Icons.verified_user_outlined : Icons.person_outline_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('profile_status_title'),
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.navy),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.t('sync_device_only'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              AppStatusChip(
                label: l10n.t('local'),
                color: AppColors.tealDark,
                background: AppColors.tealSoft,
                icon: Icons.smartphone_outlined,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
