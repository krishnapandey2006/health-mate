import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/health_campaign.dart';
import 'api_client.dart';

class CampaignLoadResult {
  final List<HealthCampaign> campaigns;
  final DateTime lastUpdated;
  final String source;
  final String? warning;
  final String? error;

  const CampaignLoadResult({
    required this.campaigns,
    required this.lastUpdated,
    required this.source,
    this.warning,
    this.error,
  });
}

class CampaignService {
  final ApiClient _api;

  CampaignService({ApiClient? api}) : _api = api ?? ApiClient();

  CampaignLoadResult? _cache;

  Future<CampaignLoadResult> load({bool forceRefresh = false}) async {
    if (!forceRefresh && _cache != null) return _cache!;

    try {
      final json = await _api.getJson('/api/campaigns', timeout: const Duration(seconds: 8));
      final rawCampaigns = json['campaigns'];
      if (rawCampaigns is List && rawCampaigns.isNotEmpty) {
        final campaigns = rawCampaigns
            .whereType<Map>()
            .map((item) => HealthCampaign.fromMap(Map<String, dynamic>.from(item)))
            .where((campaign) => campaign.title.isNotEmpty)
            .toList();
        if (campaigns.isNotEmpty) {
          final result = CampaignLoadResult(
            campaigns: campaigns,
            lastUpdated: DateTime.tryParse(json['lastUpdated']?.toString() ?? '') ?? DateTime.now(),
            source: json['source']?.toString() ?? 'HealthMate verified dataset',
            warning: json['warning']?.toString(),
          );
          _cache = result;
          return result;
        }
      }
    } on ApiException catch (error) {
      // Fall through to the bundled verified dataset. We do not pretend the
      // remote refresh succeeded.
      final bundled = await _loadBundled();
      if (bundled != null) {
        final result = CampaignLoadResult(
          campaigns: bundled.campaigns,
          lastUpdated: bundled.lastUpdated,
          source: bundled.source,
          warning: _warningFor(error),
        );
        _cache = result;
        return result;
      }
      return CampaignLoadResult(
        campaigns: const [],
        lastUpdated: DateTime.now(),
        source: 'Verified dataset',
        error: error.message,
      );
    } catch (_) {
      // Fall through to bundled data.
    }

    final bundled = await _loadBundled();
    if (bundled != null) {
      _cache = bundled;
      return bundled;
    }
    return CampaignLoadResult(
      campaigns: const [],
      lastUpdated: DateTime.now(),
      source: 'Verified dataset',
      error: 'Campaign information could not be loaded.',
    );
  }

  String _warningFor(ApiException error) {
    switch (error.type) {
      case ApiErrorType.notConfigured:
      case ApiErrorType.network:
      case ApiErrorType.timeout:
        return 'Live campaign updates are unavailable right now. Showing the last verified dataset.';
      default:
        return 'Live campaign updates could not be refreshed. Showing the last verified dataset.';
    }
  }

  Future<CampaignLoadResult?> _loadBundled() async {
    try {
      final raw = await rootBundle.loadString('assets/campaigns.json');
      final decoded = jsonDecode(raw);
      Map<String, dynamic> root;
      if (decoded is List) {
        root = {'campaigns': decoded};
      } else if (decoded is Map) {
        root = Map<String, dynamic>.from(decoded);
      } else {
        return null;
      }

      final rawCampaigns = root['campaigns'];
      if (rawCampaigns is! List) return null;
      final campaigns = rawCampaigns
          .whereType<Map>()
          .map((item) => HealthCampaign.fromMap(Map<String, dynamic>.from(item)))
          .where((campaign) => campaign.title.isNotEmpty)
          .toList();
      return CampaignLoadResult(
        campaigns: campaigns,
        lastUpdated: DateTime.tryParse(root['lastReviewed']?.toString() ?? '') ?? DateTime.now(),
        source: root['sourceNote']?.toString() ?? 'Verified public-health observance calendar',
      );
    } catch (_) {
      return null;
    }
  }

  List<CampaignView> upcoming(DateTime now, {String? cityQuery}) {
    final result = <CampaignView>[];
    for (final campaign in _cache?.campaigns ?? const <HealthCampaign>[]) {
      if (cityQuery != null && cityQuery.trim().isNotEmpty) {
        final query = cityQuery.toLowerCase();
        final haystack =
            '${campaign.city} ${campaign.venue} ${campaign.title} ${campaign.organizer}'.toLowerCase();
        if (!haystack.contains(query)) continue;
      }
      final occurrence = campaign.occurrence(now);
      if (occurrence.status != CampaignStatus.past) {
        result.add(CampaignView(
          campaign: campaign,
          start: occurrence.start,
          end: occurrence.end,
          status: occurrence.status,
        ));
      }
    }
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }

  List<CampaignView> past(DateTime now, {String? cityQuery}) {
    final result = <CampaignView>[];
    for (final campaign in _cache?.campaigns ?? const <HealthCampaign>[]) {
      if (cityQuery != null && cityQuery.trim().isNotEmpty) {
        final query = cityQuery.toLowerCase();
        final haystack =
            '${campaign.city} ${campaign.venue} ${campaign.title} ${campaign.organizer}'.toLowerCase();
        if (!haystack.contains(query)) continue;
      }
      final occurrence = campaign.previousOccurrence(now);
      result.add(CampaignView(
        campaign: campaign,
        start: occurrence.start,
        end: occurrence.end,
        status: CampaignStatus.past,
      ));
    }
    result.sort((a, b) => b.start.compareTo(a.start));
    return result;
  }
}
