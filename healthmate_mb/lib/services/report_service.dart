import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/health_report.dart';

class ReportSaveResult {
  final HealthReport report;
  final bool saved;

  const ReportSaveResult({required this.report, required this.saved});
}

/// Local-only report storage. Reports are never transmitted anywhere by this
/// service. The UI offers a user-initiated copy action instead.
class ReportService {
  static const _reportsKey = 'healthmate_reports_v2_device';
  static const _legacyLocalKey = 'healthmate_reports_v1';
  static const _localPrefix = 'healthmate_reports_v2_';
  static const _migrationFlag = 'healthmate_reports_v2_device_migrated';
  static const _lastSignatureKey = 'healthmate_last_report_signature_device';
  static const _lastSignatureTimeKey = 'healthmate_last_report_time_device';

  final SharedPreferences? _prefsOverride;

  ReportService({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<void> _migrate(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationFlag) == true) return;

    final merged = <String, HealthReport>{};
    final legacy = prefs.getString(_legacyLocalKey);
    if (legacy != null && legacy.isNotEmpty) {
      _addReportsFromJson(merged, legacy);
    }
    for (final key in prefs.getKeys().where((key) => key.startsWith(_localPrefix))) {
      final raw = prefs.getString(key);
      if (raw != null) _addReportsFromJson(merged, raw);
    }

    if (merged.isNotEmpty) {
      await prefs.setString(
        _reportsKey,
        jsonEncode(merged.values.map((report) => report.toMap()).toList()),
      );
    }
    for (final key in prefs
        .getKeys()
        .where((key) => key.startsWith(_localPrefix) && key != _reportsKey)
        .toList()) {
      await prefs.remove(key);
    }
    await prefs.remove(_legacyLocalKey);
    await prefs.setBool(_migrationFlag, true);
  }

  void _addReportsFromJson(Map<String, HealthReport> target, String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final item in decoded.whereType<Map>()) {
        final report = HealthReport.fromMap(Map<String, dynamic>.from(item));
        if (report.id.isNotEmpty) target[report.id] = report;
      }
    } catch (_) {
      // Ignore one malformed legacy entry; other local reports remain usable.
    }
  }

  Future<List<HealthReport>> loadHistory() async {
    try {
      final prefs = await _prefs();
      await _migrate(prefs);
      final raw = prefs.getString(_reportsKey);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((item) => HealthReport.fromMap(Map<String, dynamic>.from(item)))
          .where((report) => report.id.isNotEmpty)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {
      return [];
    }
  }

  Future<bool> _saveReports(List<HealthReport> reports) async {
    try {
      final prefs = await _prefs();
      final trimmed = reports.take(100).map((report) => report.toMap()).toList();
      return await prefs.setString(_reportsKey, jsonEncode(trimmed));
    } catch (_) {
      return false;
    }
  }

  Future<bool> isDuplicate(String category, String description) async {
    try {
      final prefs = await _prefs();
      final lastSignature = prefs.getString(_lastSignatureKey);
      final lastTime =
          DateTime.tryParse(prefs.getString(_lastSignatureTimeKey) ?? '');
      if (lastSignature == null || lastTime == null) return false;
      final signature = _signature(category, description);
      return lastSignature == signature &&
          DateTime.now().difference(lastTime).inSeconds < 120;
    } catch (_) {
      return false;
    }
  }

  String _signature(String category, String description) =>
      '$category|${description.trim().toLowerCase()}';

  Future<void> _rememberSignature(String category, String description) async {
    try {
      final prefs = await _prefs();
      await prefs.setString(
        _lastSignatureKey,
        _signature(category, description),
      );
      await prefs.setString(
        _lastSignatureTimeKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {
      // Duplicate protection is a convenience; the report itself is the priority.
    }
  }

  Future<ReportSaveResult> submitReport({
    required ReportType type,
    required String category,
    required String description,
    required String area,
    double? latitude,
    double? longitude,
  }) async {
    final now = DateTime.now();
    final localId = 'local_${now.millisecondsSinceEpoch}';
    final reference = 'HM-${now.millisecondsSinceEpoch.toString().substring(6)}';
    final report = HealthReport(
      id: localId,
      reference: reference,
      type: type,
      category: category,
      description: description.trim(),
      area: area.trim(),
      latitude: latitude,
      longitude: longitude,
      createdAt: now,
    );

    final existing = await loadHistory();
    final saved = await _saveReports([
      report,
      ...existing.where((item) => item.id != report.id),
    ]);
    if (saved) {
      await _rememberSignature(category, description);
    }
    return ReportSaveResult(report: report, saved: saved);
  }

  Future<bool> clearAll() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(_reportsKey);
      await prefs.remove(_lastSignatureKey);
      await prefs.remove(_lastSignatureTimeKey);
      return true;
    } catch (_) {
      return false;
    }
  }
}
