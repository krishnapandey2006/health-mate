import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/article.dart';

void main() {
  test('article parsing strips HTML and accepts only safe http links', () {
    final article = Article.fromMap({
      'id': 'article-1',
      'title': '<b>WHO updates guidance</b>',
      'source': 'WHO',
      'publishedAt': '2026-10-20T08:00:00.000Z',
      'summary': '<p>A short summary.</p>',
      'link': 'https://www.who.int/news/item/example',
      'thumbnail': 'https://www.who.int/images/example.jpg',
      'category': 'public_health',
    });

    expect(article.title, 'WHO updates guidance');
    expect(article.summary, 'A short summary.');
    expect(article.link, startsWith('https://'));
    expect(article.thumbnail, startsWith('https://'));
    expect(article.isValid, isTrue);
  });

  test('article with a javascript link is rejected as unsafe', () {
    final article = Article.fromMap({
      'title': 'Unsafe link',
      'source': 'Unknown',
      'publishedAt': '2026-10-20T08:00:00.000Z',
      'summary': 'Summary',
      'link': 'javascript:alert(1)',
      'thumbnail': 'javascript:alert(1)',
    });

    expect(article.link, isNull);
    expect(article.thumbnail, isNull);
  });

  test('article without a valid publication date is not considered valid', () {
    final article = Article.fromMap({
      'title': 'Undated',
      'source': 'Unknown',
      'publishedAt': 'not-a-date',
      'summary': 'Summary',
    });

    expect(article.isValid, isFalse);
  });
}
