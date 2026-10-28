import 'dart:convert';

import 'package:hive/hive.dart';

import '../models/article.dart';
import 'api_client.dart';

class NewsResult {
  final List<Article> articles;
  final int page;
  final bool hasMore;
  final int total;
  final DateTime? lastUpdated;
  final bool fromCache;
  final String? warning;
  final ApiException? error;

  const NewsResult({
    required this.articles,
    this.page = 1,
    this.hasMore = false,
    this.total = 0,
    this.lastUpdated,
    this.fromCache = false,
    this.warning,
    this.error,
  });

  bool get isError => error != null;
  bool get isEmpty => articles.isEmpty && error == null;
}

class NewsService {
  static const _boxName = 'news_cache_v3';
  final ApiClient _api;

  NewsService({ApiClient? api}) : _api = api ?? ApiClient();

  String _cacheKey(String category, String lang, int page) =>
      '${lang}_${category}_$page';

  Future<NewsResult> fetchPage({
    String category = 'all',
    String lang = 'en',
    int page = 1,
    int limit = 20,
    bool forceRefresh = false,
  }) async {
    final cached = await loadCachedPage(category: category, lang: lang, page: page);

    if (!forceRefresh && cached != null) {
      return cached;
    }

    try {
      final json = await _api.getJson(
        '/api/news',
        query: {
          'category': category,
          'lang': lang,
          'page': '$page',
          'limit': '$limit',
        },
        // The proxy also fetches publisher pages for thumbnails (up to 4.5s
        // each) before it replies, so the client budget must cover that.
        timeout: const Duration(seconds: 25),
      );

      final rawArticles = json['articles'];
      final articles = <Article>[];
      if (rawArticles is List) {
        for (final item in rawArticles) {
          if (item is Map) {
            final article = Article.fromMap(Map<String, dynamic>.from(item));
            if (article.isValid) articles.add(article);
          }
        }
      }

      final result = NewsResult(
        articles: articles,
        page: _asInt(json['page'], page),
        hasMore: json['hasMore'] == true,
        total: _asInt(json['total'], articles.length),
        lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? ''),
        warning: json['warning']?.toString(),
      );

      if (articles.isNotEmpty) {
        await _cachePage(category, lang, page, result);
      }
      return result;
    } on ApiException catch (error) {
      if (cached != null && cached.articles.isNotEmpty) {
        return NewsResult(
          articles: cached.articles,
          page: cached.page,
          hasMore: cached.hasMore,
          total: cached.total,
          lastUpdated: cached.lastUpdated,
          fromCache: true,
          warning: _warningFor(error),
          error: error,
        );
      }
      return NewsResult(
        articles: const [],
        page: page,
        lastUpdated: null,
        error: error,
      );
    }
  }

  String _warningFor(ApiException error) {
    switch (error.type) {
      case ApiErrorType.notConfigured:
        return 'Live news is not configured. Showing the last saved articles.';
      case ApiErrorType.network:
      case ApiErrorType.timeout:
        return 'You appear to be offline. Showing the last saved articles.';
      case ApiErrorType.rateLimit:
        return 'The news service is busy. Showing the last saved articles.';
      default:
        return 'Live news could not be refreshed. Showing the last saved articles.';
    }
  }

  Future<NewsResult?> loadCachedPage({
    String category = 'all',
    String lang = 'en',
    int page = 1,
  }) async {
    try {
      final box = await Hive.openBox(_boxName);
      final raw = box.get(_cacheKey(category, lang, page));
      if (raw is! String || raw.isEmpty) return null;
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      final articles = <Article>[];
      final rawArticles = json['articles'];
      if (rawArticles is List) {
        for (final item in rawArticles) {
          if (item is Map) {
            final article = Article.fromMap(Map<String, dynamic>.from(item));
            if (article.isValid) articles.add(article);
          }
        }
      }
      return NewsResult(
        articles: articles,
        page: _asInt(json['page'], page),
        hasMore: json['hasMore'] == true,
        total: _asInt(json['total'], articles.length),
        lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? ''),
        fromCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cachePage(String category, String lang, int page, NewsResult result) async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.put(
        _cacheKey(category, lang, page),
        jsonEncode({
          'articles': result.articles.map((article) => article.toMap()).toList(),
          'page': result.page,
          'hasMore': result.hasMore,
          'total': result.total,
          'lastUpdated': (result.lastUpdated ?? DateTime.now()).toIso8601String(),
        }),
      );
    } catch (_) {
      // Caching is best-effort; a failure must not hide live results.
    }
  }

  Future<DateTime?> lastSuccessfulUpdate({String category = 'all', String lang = 'en'}) async {
    final cached = await loadCachedPage(category: category, lang: lang);
    return cached?.lastUpdated;
  }

  Future<void> clearCache() async {
    try {
      final box = await Hive.openBox(_boxName);
      await box.clear();
    } catch (_) {}
  }

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
