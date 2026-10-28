import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app/theme.dart';
import '../l10n/app_localizations.dart';
import '../language_provider.dart';
import '../models/article.dart';
import '../services/app_settings_provider.dart';
import '../services/tts_service.dart';
import '../widgets/app_widgets.dart';

class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  final TTSService _tts = TTSService();
  bool _speaking = false;

  Future<void> _toggleSpeech() async {
    final l10n = AppLocalizations.of(context);
    final settings = context.read<AppSettingsProvider>();
    if (!settings.voiceGuidance) {
      showAppSnackBar(context, l10n.t('voice_guidance_off'), isError: true);
      return;
    }
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    try {
      await _tts.speak(
        '${widget.article.title}. ${widget.article.summary}',
        lang: context.read<LanguageProvider>().languageCode,
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, l10n.t('tts_unavailable'), isError: true);
      }
    } finally {
      if (mounted) setState(() => _speaking = false);
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '${widget.article.title}\n\n${widget.article.summary}\n\n${widget.article.link ?? ''}',
        ),
      );
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, AppLocalizations.of(context).t('share_failed'), isError: true);
      }
    }
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final article = widget.article;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('article_title')),
        actions: [
          IconButton(
            tooltip: l10n.t('listen'),
            onPressed: _toggleSpeech,
            icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.headphones_outlined),
          ),
          IconButton(
            tooltip: l10n.t('share'),
            onPressed: _share,
            icon: const Icon(Icons.share_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 820,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (article.thumbnail != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      article.thumbnail!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.tealSoft,
                        child: const Center(
                          child: Icon(Icons.health_and_safety_outlined, size: 52, color: AppColors.teal),
                        ),
                      ),
                    ),
                  ),
                ),
              if (article.thumbnail != null) const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppStatusChip(
                    label: article.source,
                    color: AppColors.tealDark,
                    background: AppColors.tealSoft,
                    icon: Icons.public_rounded,
                  ),
                  AppStatusChip(
                    label: formatDateTime(article.publishedDate),
                    color: AppColors.slate,
                    background: const Color(0xFFF0F5F3),
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                article.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 27,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                article.summary.isEmpty ? l10n.t('article_no_summary') : article.summary,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.7),
              ),
              const SizedBox(height: 22),
              if (article.link != null) ...[
                FilledButton.icon(
                  onPressed: () => openExternalUrl(
                    context,
                    article.link,
                    failureMessage: l10n.t('article_link_failed'),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(l10n.t('read_full_article')),
                ),
                const SizedBox(height: 12),
              ],
              AppInfoBanner(
                icon: Icons.info_outline_rounded,
                text: l10n.t('news_source_disclaimer'),
                color: AppColors.slate,
                background: const Color(0xFFF0F5F3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
