import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'language_provider.dart';
import 'l10n/app_localizations.dart';
import 'models/article.dart';
import 'screens/article_detail.dart';
import 'services/news_service.dart';
import 'widgets/app_widgets.dart';

class HealthNewsScreen extends StatefulWidget {
  final Article? initialArticle;

  const HealthNewsScreen({super.key, this.initialArticle});

  @override
  State<HealthNewsScreen> createState() => _HealthNewsScreenState();
}

class _HealthNewsScreenState extends State<HealthNewsScreen> {
  static const _categories = [
    'all',
    'public_health',
    'research',
    'prevention',
    'vaccination',
    'healthcare',
  ];

  final NewsService _newsService = NewsService();
  final ScrollController _scrollController = ScrollController();

  List<Article> _articles = const [];
  String _category = 'all';
  String _languageCode = 'en';
  int _page = 1;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  bool _fromCache = false;
  String? _error;
  String? _warning;
  DateTime? _lastUpdated;
  int _requestToken = 0;
  bool _openedInitial = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load(reset: true, preferCache: true);
      if (widget.initialArticle != null && !_openedInitial) {
        _openedInitial = true;
        _openArticle(widget.initialArticle!);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final code = context.watch<LanguageProvider>().languageCode;
    if (code != _languageCode) {
      _languageCode = code;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Clear articles from the previous language so a stale headline cannot
        // appear under the new language while the fresh page is loading.
        setState(() {
          _articles = const [];
          _page = 1;
          _hasMore = false;
          _lastUpdated = null;
          _loading = true;
          _loadingMore = false;
          _error = null;
          _warning = null;
          _fromCache = false;
        });
        _load(reset: true, preferCache: true);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset, bool force = false, bool preferCache = false}) async {
    final token = ++_requestToken;
    final l10n = AppLocalizations.of(context);

    if (reset) {
      setState(() {
        _loading = _articles.isEmpty;
        _error = null;
        if (force) _warning = null;
      });
    }

    if (reset && preferCache) {
      final cached = await _newsService.loadCachedPage(
        category: _category,
        lang: _languageCode,
        page: 1,
      );
      if (!mounted || token != _requestToken) return;
      if (cached != null && cached.articles.isNotEmpty) {
        setState(() {
          _articles = cached.articles;
          _page = 1;
          _hasMore = cached.hasMore;
          _lastUpdated = cached.lastUpdated;
          _fromCache = true;
          _loading = false;
        });
      }
    }

    final result = await _newsService.fetchPage(
      category: _category,
      lang: _languageCode,
      page: reset ? 1 : _page + 1,
      limit: 12,
      forceRefresh: force || reset,
    );

    if (!mounted || token != _requestToken) return;

    if (result.isError && result.articles.isEmpty) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = result.error?.message ?? l10n.t('news_error_generic');
        _warning = null;
        _fromCache = false;
      });
      return;
    }

    final combined = reset ? result.articles : _merge(_articles, result.articles);
    setState(() {
      _loading = false;
      _loadingMore = false;
      _articles = combined;
      _page = result.page;
      _hasMore = result.hasMore;
      _lastUpdated = result.lastUpdated ?? _lastUpdated;
      _fromCache = result.fromCache;
      _warning = result.warning;
      _error = null;
    });
  }

  List<Article> _merge(List<Article> existing, List<Article> incoming) {
    final seen = <String>{};
    final result = <Article>[];
    for (final article in [...existing, ...incoming]) {
      final key = article.link ?? '${article.title}|${article.source}';
      if (seen.add(key)) result.add(article);
    }
    return result;
  }

  Future<void> _refresh() => _load(reset: true, force: true);

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    await _load(reset: false, force: true);
  }

  void _openArticle(Article article) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }

  void _selectCategory(String category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _articles = const [];
      _page = 1;
      _hasMore = false;
      _lastUpdated = null;
      _loading = true;
      _error = null;
      _warning = null;
    });
    _load(reset: true, force: true);
  }

  String _categoryLabel(AppLocalizations l10n, String category) {
    switch (category) {
      case 'public_health':
        return l10n.t('category_public_health');
      case 'research':
        return l10n.t('category_research');
      case 'prevention':
        return l10n.t('category_prevention');
      case 'vaccination':
        return l10n.t('category_vaccination');
      case 'healthcare':
        return l10n.t('category_healthcare');
      default:
        return l10n.t('all');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('topStories')),
        actions: [
          IconButton(
            tooltip: l10n.t('refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: ResponsiveBody(
                maxWidth: 920,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.t('news_intro'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final category = _categories[index];
                          return ChoiceChip(
                            label: Text(_categoryLabel(l10n, category)),
                            selected: _category == category,
                            onSelected: (_) => _selectCategory(category),
                          );
                        },
                      ),
                    ),
                    if (_lastUpdated != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _fromCache ? Icons.history_rounded : Icons.check_circle_outline_rounded,
                            size: 13,
                            color: AppColors.muted,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${_fromCache ? l10n.t('saved_articles') : l10n.t('last_updated')} ${formatShortDate(_lastUpdated!, l10n)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (_warning != null) ...[
                      const SizedBox(height: 12),
                      AppInfoBanner(
                        icon: Icons.info_outline_rounded,
                        text: _warning!,
                        color: AppColors.warning,
                        background: AppColors.warningSoft,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_loading)
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: const Column(
                    children: [
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                      SizedBox(height: 10),
                      ArticleSkeleton(),
                    ],
                  ),
                ),
              )
            else if (_articles.isEmpty && _error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppErrorState(
                  title: l10n.t('news_unavailable'),
                  message: _error!,
                  onRetry: _refresh,
                ),
              )
            else if (_articles.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.newspaper_outlined,
                  title: l10n.t('no_articles_title'),
                  message: l10n.t('no_articles_body'),
                  actionLabel: l10n.t('retry'),
                  onAction: _refresh,
                ),
              )
            else
              SliverToBoxAdapter(
                child: ResponsiveBody(
                  maxWidth: 920,
                  child: Column(
                    children: [
                      for (var i = 0; i < _articles.length; i++) ...[
                        _NewsCard(
                          article: _articles[i],
                          categoryLabel: _categoryLabel(l10n, _articles[i].category),
                          onTap: () => _openArticle(_articles[i]),
                        ),
                        if (i != _articles.length - 1) const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 16),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        )
                      else if (_hasMore)
                        OutlinedButton.icon(
                          onPressed: _loadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(l10n.t('load_more')),
                        )
                      else
                        Text(
                          l10n.t('all_caught_up'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 20),
                      AppInfoBanner(
                        icon: Icons.public_rounded,
                        text: l10n.t('news_source_disclaimer'),
                        color: AppColors.slate,
                        background: const Color(0xFFF0F5F3),
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

class _NewsCard extends StatelessWidget {
  final Article article;
  final String categoryLabel;
  final VoidCallback onTap;

  const _NewsCard({
    required this.article,
    required this.categoryLabel,
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
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: article.thumbnail == null
                          ? Container(
                              color: AppColors.tealSoft,
                              child: const Icon(Icons.health_and_safety_outlined, color: AppColors.teal, size: 30),
                            )
                          : Image.network(
                              article.thumbnail!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: AppColors.tealSoft,
                                child: const Icon(Icons.health_and_safety_outlined, color: AppColors.teal, size: 30),
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
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                            height: 1.32,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          article.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      article.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.tealDark,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '· ${formatShortDate(article.publishedDate, l10n)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F5F3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      categoryLabel,
                      style: const TextStyle(fontSize: 10, color: AppColors.slate, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new_rounded, size: 14, color: AppColors.muted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
