import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import '../models/vaccination_record.dart';

enum VaccineStatus { recorded, upcoming, noRecord, notApplicable }

class VaccineScheduleItem {
  final String id;
  final String name;
  final String ageLabel;
  final int? dueMonths;
  final String description;
  final String? femaleOnly;
  final bool generalInfoOnly;

  const VaccineScheduleItem({
    required this.id,
    required this.name,
    required this.ageLabel,
    required this.dueMonths,
    required this.description,
    this.femaleOnly,
    this.generalInfoOnly = false,
  });
}

class VaccineRecommendation {
  final VaccineScheduleItem item;
  final VaccineStatus status;
  final VaccinationRecord? record;

  const VaccineRecommendation({
    required this.item,
    required this.status,
    this.record,
  });

  bool get isPersonalAction =>
      status == VaccineStatus.upcoming || status == VaccineStatus.noRecord;
}

/// India's National Immunization Schedule (NIS), MoHFW/NHM.
///
/// This is reference information. It never labels a vaccine "overdue" when no
/// record exists. Doses whose age has passed without a saved record are shown
/// as "No record on file", not as missed.
class VaccineService {
  static const sourceName = 'National Immunization Schedule, MoHFW / NHM (India)';
  static const sourceUrl =
      'https://nhm.gov.in/index1.php?lang=1&level=2&sublinkid=824&lid=220';

  /// Future doses more than this far away are reference information, not a
  /// near-term personal action.
  static const _upcomingWindowMonths = 24;

  static const schedule = <VaccineScheduleItem>[
    VaccineScheduleItem(
      id: 'bcg',
      name: 'BCG',
      ageLabel: 'At birth',
      dueMonths: 0,
      description: 'Protects against severe tuberculosis in infants.',
    ),
    VaccineScheduleItem(
      id: 'opv0',
      name: 'OPV-0',
      ageLabel: 'At birth',
      dueMonths: 0,
      description: 'Oral polio vaccine, birth dose.',
    ),
    VaccineScheduleItem(
      id: 'hepb_birth',
      name: 'Hepatitis B birth dose',
      ageLabel: 'Within 24 hours of birth',
      dueMonths: 0,
      description: 'Birth dose of hepatitis B vaccine.',
    ),
    VaccineScheduleItem(
      id: 'penta1',
      name: 'Pentavalent-1',
      ageLabel: '6 weeks',
      dueMonths: 2,
      description: 'DPT + hepatitis B + Hib, first dose.',
    ),
    VaccineScheduleItem(
      id: 'opv1',
      name: 'OPV-1',
      ageLabel: '6 weeks',
      dueMonths: 2,
      description: 'Oral polio vaccine, first dose.',
    ),
    VaccineScheduleItem(
      id: 'rotavirus1',
      name: 'Rotavirus-1',
      ageLabel: '6 weeks',
      dueMonths: 2,
      description: 'Protects against severe rotavirus diarrhoea.',
    ),
    VaccineScheduleItem(
      id: 'pcv1',
      name: 'PCV-1',
      ageLabel: '6 weeks',
      dueMonths: 2,
      description: 'Pneumococcal conjugate vaccine, first dose.',
    ),
    VaccineScheduleItem(
      id: 'ipv1',
      name: 'fIPV-1',
      ageLabel: '6 weeks',
      dueMonths: 2,
      description: 'Fractional injectable polio vaccine, first dose.',
    ),
    VaccineScheduleItem(
      id: 'penta2',
      name: 'Pentavalent-2',
      ageLabel: '10 weeks',
      dueMonths: 3,
      description: 'Second dose of the pentavalent vaccine.',
    ),
    VaccineScheduleItem(
      id: 'opv2',
      name: 'OPV-2',
      ageLabel: '10 weeks',
      dueMonths: 3,
      description: 'Oral polio vaccine, second dose.',
    ),
    VaccineScheduleItem(
      id: 'rotavirus2',
      name: 'Rotavirus-2',
      ageLabel: '10 weeks',
      dueMonths: 3,
      description: 'Second rotavirus dose.',
    ),
    VaccineScheduleItem(
      id: 'penta3',
      name: 'Pentavalent-3',
      ageLabel: '14 weeks',
      dueMonths: 4,
      description: 'Third dose of the pentavalent vaccine.',
    ),
    VaccineScheduleItem(
      id: 'opv3',
      name: 'OPV-3',
      ageLabel: '14 weeks',
      dueMonths: 4,
      description: 'Oral polio vaccine, third dose.',
    ),
    VaccineScheduleItem(
      id: 'rotavirus3',
      name: 'Rotavirus-3',
      ageLabel: '14 weeks',
      dueMonths: 4,
      description: 'Third rotavirus dose.',
    ),
    VaccineScheduleItem(
      id: 'pcv2',
      name: 'PCV-2',
      ageLabel: '14 weeks',
      dueMonths: 4,
      description: 'Second pneumococcal conjugate dose.',
    ),
    VaccineScheduleItem(
      id: 'ipv2',
      name: 'fIPV-2',
      ageLabel: '14 weeks',
      dueMonths: 4,
      description: 'Fractional injectable polio vaccine, second dose.',
    ),
    VaccineScheduleItem(
      id: 'mr1',
      name: 'Measles-Rubella-1',
      ageLabel: '9–12 months',
      dueMonths: 9,
      description: 'First measles-rubella dose.',
    ),
    VaccineScheduleItem(
      id: 'je1',
      name: 'JE-1',
      ageLabel: '9–12 months (endemic districts)',
      dueMonths: 9,
      description:
          'Japanese encephalitis vaccine where recommended by the state programme.',
    ),
    VaccineScheduleItem(
      id: 'pcv_booster',
      name: 'PCV booster',
      ageLabel: '9–12 months',
      dueMonths: 9,
      description: 'Pneumococcal booster dose.',
    ),
    VaccineScheduleItem(
      id: 'mr2',
      name: 'Measles-Rubella-2',
      ageLabel: '16–24 months',
      dueMonths: 16,
      description: 'Second measles-rubella dose.',
    ),
    VaccineScheduleItem(
      id: 'je2',
      name: 'JE-2',
      ageLabel: '16–24 months (endemic districts)',
      dueMonths: 16,
      description: 'Second Japanese encephalitis dose where recommended.',
    ),
    VaccineScheduleItem(
      id: 'dpt_booster1',
      name: 'DPT booster-1',
      ageLabel: '16–24 months',
      dueMonths: 16,
      description:
          'First booster of diphtheria, pertussis and tetanus vaccine.',
    ),
    VaccineScheduleItem(
      id: 'opv_booster',
      name: 'OPV booster',
      ageLabel: '16–24 months',
      dueMonths: 16,
      description: 'Polio booster dose.',
    ),
    VaccineScheduleItem(
      id: 'dpt_booster2',
      name: 'DPT booster-2',
      ageLabel: '5–6 years',
      dueMonths: 60,
      description: 'Second DPT booster before school age.',
    ),
    VaccineScheduleItem(
      id: 'td_10',
      name: 'Td (10 years)',
      ageLabel: '10 years',
      dueMonths: 120,
      description: 'Tetanus and adult diphtheria vaccine.',
    ),
    VaccineScheduleItem(
      id: 'td_16',
      name: 'Td (16 years)',
      ageLabel: '16 years',
      dueMonths: 192,
      description: 'Tetanus and adult diphtheria vaccine.',
    ),
    VaccineScheduleItem(
      id: 'hpv',
      name: 'HPV',
      ageLabel: '9–14 years (girls)',
      dueMonths: 108,
      description:
          'Human papillomavirus vaccine as part of the national programme; two doses.',
      femaleOnly: 'female',
    ),
    VaccineScheduleItem(
      id: 'influenza_60',
      name: 'Influenza (annual)',
      ageLabel: '60 years and above',
      dueMonths: 720,
      description:
          'Annual influenza vaccination may be advised by a clinician for older adults.',
    ),
    VaccineScheduleItem(
      id: 'tt_pregnancy',
      name: 'TT / Td in pregnancy',
      ageLabel: 'During pregnancy',
      dueMonths: null,
      description:
          'Two doses or a booster as advised by your health worker.',
      generalInfoOnly: true,
    ),
  ];

  static List<VaccineRecommendation> recommendationsFor(
    UserProfile profile,
    List<VaccinationRecord> records,
  ) {
    final ageMonths = profile.ageInMonths;
    final byId = {for (final record in records) record.vaccineId: record};

    return schedule.map((item) {
      final record = byId[item.id];
      if (record != null) {
        return VaccineRecommendation(
          item: item,
          status: VaccineStatus.recorded,
          record: record,
        );
      }

      if (item.generalInfoOnly) {
        return VaccineRecommendation(
          item: item,
          status: VaccineStatus.notApplicable,
        );
      }
      if (item.femaleOnly != null && profile.gender != item.femaleOnly) {
        return VaccineRecommendation(
          item: item,
          status: VaccineStatus.notApplicable,
        );
      }
      if (ageMonths == null || item.dueMonths == null) {
        return VaccineRecommendation(
          item: item,
          status: VaccineStatus.notApplicable,
        );
      }

      final difference = item.dueMonths! - ageMonths;
      if (difference > _upcomingWindowMonths) {
        return VaccineRecommendation(
          item: item,
          status: VaccineStatus.notApplicable,
        );
      }
      if (difference > 0) {
        return VaccineRecommendation(
          item: item,
          status: VaccineStatus.upcoming,
        );
      }
      // A dose whose age has passed but has no saved record is not marked
      // missed or overdue. It stays visible as "No record on file" so the user
      // can check a vaccination card or ask a health worker.
      return VaccineRecommendation(
        item: item,
        status: VaccineStatus.noRecord,
      );
    }).toList();
  }

  /// Reference-only recommendations when the user has no profile or date of
  /// birth. Saved records are still shown as recorded; no age-based status is
  /// invented without a date of birth.
  static List<VaccineRecommendation> recommendationsWithoutAge(
    List<VaccinationRecord> records,
  ) {
    final byId = {for (final record in records) record.vaccineId: record};
    return schedule.map((item) {
      final record = byId[item.id];
      return VaccineRecommendation(
        item: item,
        status:
            record == null ? VaccineStatus.notApplicable : VaccineStatus.recorded,
        record: record,
      );
    }).toList();
  }

  static String statusLabel(VaccineStatus status) {
    switch (status) {
      case VaccineStatus.recorded:
        return 'Recorded';
      case VaccineStatus.upcoming:
        return 'Upcoming';
      case VaccineStatus.noRecord:
        return 'No record on file';
      case VaccineStatus.notApplicable:
        return 'General information';
    }
  }

  static String statusExplanation(VaccineStatus status) {
    switch (status) {
      case VaccineStatus.recorded:
        return 'You have saved a date for this vaccination.';
      case VaccineStatus.upcoming:
        return 'This dose is scheduled for a later age.';
      case VaccineStatus.noRecord:
        return 'No date is saved. This does not mean the dose was missed — check your vaccination card or ask a health worker.';
      case VaccineStatus.notApplicable:
        return 'This entry is general schedule information, not a personal recommendation.';
    }
  }
}

/// Stores vaccination records locally only. No record is invented and no status
/// is shown as "overdue" without a saved record.
class VaccinationRepository {
  static const _key = 'healthmate_vaccinations_v2_device';
  static const _legacyPrefix = 'healthmate_vaccinations_v1_';
  static const _migrationFlag = 'healthmate_vaccinations_v2_migrated';

  final SharedPreferences? _prefsOverride;

  VaccinationRepository({SharedPreferences? prefs}) : _prefsOverride = prefs;

  Future<SharedPreferences> _prefs() async =>
      _prefsOverride ?? await SharedPreferences.getInstance();

  Future<void> _migrate(SharedPreferences prefs) async {
    if (prefs.getBool(_migrationFlag) == true) return;
    final merged = <String, VaccinationRecord>{};
    for (final key in prefs
        .getKeys()
        .where((key) => key.startsWith(_legacyPrefix))) {
      final raw = prefs.getString(key);
      if (raw == null) continue;
      for (final record in _decode(raw)) {
        merged[record.vaccineId] = record;
      }
    }
    if (merged.isNotEmpty) {
      await prefs.setString(
        _key,
        jsonEncode(merged.values.map((record) => record.toMap()).toList()),
      );
    }
    for (final key in prefs
        .getKeys()
        .where((key) => key.startsWith(_legacyPrefix))
        .toList()) {
      await prefs.remove(key);
    }
    await prefs.setBool(_migrationFlag, true);
  }

  List<VaccinationRecord> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <VaccinationRecord>[];
      return decoded
          .whereType<Map>()
          .map((item) => VaccinationRecord.fromMap(Map<String, dynamic>.from(item)))
          .where((record) => record.vaccineId.isNotEmpty)
          .toList();
    } catch (_) {
      return <VaccinationRecord>[];
    }
  }

  Future<List<VaccinationRecord>> load() async {
    try {
      final prefs = await _prefs();
      await _migrate(prefs);
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return <VaccinationRecord>[];
      return _decode(raw);
    } catch (_) {
      return <VaccinationRecord>[];
    }
  }

  Future<bool> save(VaccinationRecord record) async {
    try {
      final records = await load();
      records.removeWhere((item) => item.vaccineId == record.vaccineId);
      records.add(record);
      final prefs = await _prefs();
      return await prefs.setString(
        _key,
        jsonEncode(records.map((item) => item.toMap()).toList()),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> delete(String vaccineId) async {
    try {
      final records = await load();
      records.removeWhere((item) => item.vaccineId == vaccineId);
      final prefs = await _prefs();
      return await prefs.setString(
        _key,
        jsonEncode(records.map((item) => item.toMap()).toList()),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(_key);
      return true;
    } catch (_) {
      return false;
    }
  }
}
