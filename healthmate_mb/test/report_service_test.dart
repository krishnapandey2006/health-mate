import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/health_report.dart';
import 'package:healthmate_mb/services/report_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ReportService> service() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return ReportService(prefs: prefs);
  }

  test('signed-out report is saved locally with a local reference only', () async {
    final reportService = await service();
    final result = await reportService.submitReport(
      type: ReportType.personalConcern,
      category: 'vaccination',
      description: 'The vaccine stock was unavailable at the clinic today.',
      area: 'Pune',
      uid: null,
    );

    expect(result.cloudSaved, isFalse);
    expect(result.issue, ReportSaveIssue.signedOut);
    expect(result.report.reference, startsWith('LOCAL-'));
    expect(result.report.status, ReportStatus.pendingSync);

    final local = await reportService.loadLocalReports(uid: null);
    expect(local, hasLength(1));
    expect(local.single.description, contains('vaccine stock'));
  });

  test('device reports are not leaked into a signed-in account history', () async {
    final reportService = await service();
    await reportService.submitReport(
      type: ReportType.personalConcern,
      category: 'vaccination',
      description: 'This report belongs to the device-only session.',
      area: '',
      uid: null,
    );

    final deviceHistory = await reportService.loadHistory(null);
    final signedInHistory = await reportService.loadHistory('user-a');

    expect(deviceHistory, hasLength(1));
    expect(signedInHistory, isEmpty);
  });

  test('duplicate protection is scoped to the account key', () async {
    final reportService = await service();
    const description = 'A sufficiently long description for duplicate checking.';

    await reportService.submitReport(
      type: ReportType.feedback,
      category: 'other',
      description: description,
      area: '',
      uid: null,
    );

    expect(await reportService.isDuplicate(null, 'other', description), isTrue);
    expect(await reportService.isDuplicate('user-a', 'other', description), isFalse);
  });

  test('cloud-not-configured is reported truthfully and still saves locally', () async {
    final reportService = await service();
    final result = await reportService.submitReport(
      type: ReportType.feedback,
      category: 'other',
      description: 'The app should explain when cloud submission is unavailable.',
      area: '',
      uid: 'user-a',
    );

    expect(result.cloudSaved, isFalse);
    expect(result.issue, ReportSaveIssue.cloudNotConfigured);
    expect(result.report.reference, startsWith('LOCAL-'));

    final local = await reportService.loadLocalReports(uid: 'user-a');
    expect(local, hasLength(1));
  });

  test('legacy local reports migrate to the device-only store', () async {
    final legacy = [
      {
        'id': 'local_1',
        'reference': 'LOCAL-1',
        'uid': '',
        'type': 'personalConcern',
        'category': 'vaccination',
        'description': 'A legacy report that should remain available offline.',
        'area': '',
        'status': 'pendingSync',
        'createdAt': '2026-01-01T10:00:00.000',
      },
    ];
    SharedPreferences.setMockInitialValues({
      'healthmate_reports_v1': jsonEncode(legacy),
    });
    final prefs = await SharedPreferences.getInstance();
    final reportService = ReportService(prefs: prefs);

    final reports = await reportService.loadLocalReports(uid: null);
    expect(reports, hasLength(1));
    expect(reports.single.id, 'local_1');
    expect(prefs.getString('healthmate_reports_v1'), isNull);
  });
}
