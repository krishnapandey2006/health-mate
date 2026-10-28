class Article {
  final String id;
  final String title;
  final String source;
  final String publishedAt;
  final String summary;
  final String severity; // 'CRITICAL' | 'ADVISORY' | 'TIP'
  final String? link;
  final String? language;
  final String? thumbnail;
  final String category;

  DateTime get publishedDate {
    final parsed = DateTime.tryParse(publishedAt);
    if (parsed != null) return parsed;
    final cleaned = publishedAt.replaceAll(' GMT', '');
    return DateTime.tryParse(cleaned) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  const Article({
    required this.id,
    required this.title,
    required this.source,
    required this.publishedAt,
    required this.summary,
    this.severity = 'ADVISORY',
    this.link,
    this.language,
    this.thumbnail,
    this.category = 'all',
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    final link = _safeUrl(map['link'] ?? map['url']);
    final image = _safeUrl(map['thumbnail'] ?? map['image'] ?? map['urlToImage']);
    return Article(
      id: (map['id'] ?? link ?? map['title'] ?? '').toString(),
      title: _stripHtml((map['title'] ?? '').toString()),
      source: (map['source'] ?? map['sourceName'] ?? 'Unknown source').toString(),
      publishedAt: (map['publishedAt'] ?? map['pubDate'] ?? '').toString(),
      summary: _stripHtml((map['description'] ?? map['summary'] ?? map['content'] ?? '').toString()),
      severity: (map['severity'] ?? 'ADVISORY').toString(),
      link: link,
      language: map['language']?.toString(),
      thumbnail: image,
      category: (map['category'] ?? 'all').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'source': source,
        'publishedAt': publishedAt,
        'summary': summary,
        'severity': severity,
        if (link != null) 'link': link,
        if (language != null) 'language': language,
        if (thumbnail != null) 'thumbnail': thumbnail,
        'category': category,
      };

  bool get isValid =>
      title.trim().isNotEmpty && publishedDate.millisecondsSinceEpoch > 0;

  static String? _safeUrl(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    var candidate = raw;
    if (candidate.startsWith('//')) candidate = 'https:$candidate';
    final uri = Uri.tryParse(candidate);
    if (uri == null || !uri.hasScheme || !uri.isAbsolute) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    return uri.toString();
  }

  static String _stripHtml(String raw) {
    var value = raw
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'https?:\/\/\S+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (value.length > 420) value = '${value.substring(0, 417)}...';
    return value;
  }
}
