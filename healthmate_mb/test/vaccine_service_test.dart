import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/user_profile.dart';
import 'package:healthmate_mb/models/vaccination_record.dart';
import 'package:healthmate_mb/services/vaccine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserProfile profileWithAge({
    required int years,
    required int months,
    String gender = 'female',
  }) {
    final now = DateTime.now();
    final dob = DateTime(now.year - years, now.month - months, now.day);
    return UserProfile(
      firstName: 'Test',
      lastName: 'User',
      dateOfBirth: dob,
      gender: gender,
      state: 'Delhi',
    );
  }

  test('schedule includes birth doses and a trusted source', () {
    final ids = VaccineService.schedule.map((item) => item.id).toSet();
    expect(ids, containsAll(<String>['bcg', 'opv0', 'hepb_birth']));
    expect(VaccineService.sourceName, contains('National Immunization Schedule'));
    expect(VaccineService.sourceUrl, startsWith('https://'));
  });

  test('recommendationsFor marks birth doses as no record, not overdue', () {
    final profile = profileWithAge(years: 0, months: 1);
    final recommendations = VaccineService.recommendationsFor(profile, const []);

    final bcg = recommendations.firstWhere((item) => item.item.id == 'bcg');
    expect(bcg.status, VaccineStatus.noRecord);
    expect(VaccineService.statusLabel(bcg.status), 'No record on file');
    expect(VaccineService.statusExplanation(bcg.status).toLowerCase(), isNot(contains('overdue')));
  });

  test('recommendationsFor marks future doses as upcoming', () {
    final profile = profileWithAge(years: 0, months: 1);
    final recommendations = VaccineService.recommendationsFor(profile, const []);

    final penta1 = recommendations.firstWhere((item) => item.item.id == 'penta1');
    expect(penta1.status, VaccineStatus.upcoming);
  });

  test('recommendationsFor uses saved records as the source of truth', () {
    final profile = profileWithAge(years: 0, months: 2);
    final record = VaccinationRecord(vaccineId: 'bcg', date: DateTime(2026, 1, 2));
    final recommendations = VaccineService.recommendationsFor(profile, [record]);

    final bcg = recommendations.firstWhere((item) => item.item.id == 'bcg');
    expect(bcg.status, VaccineStatus.recorded);
    expect(bcg.record?.date, DateTime(2026, 1, 2));
  });

  test('HPV is only recommended for girls in the eligible age group', () {
    final girl = profileWithAge(years: 16, months: 0, gender: 'female');
    final boy = profileWithAge(years: 16, months: 0, gender: 'male');

    final girlHpv = VaccineService.recommendationsFor(girl, const [])
        .firstWhere((item) => item.item.id == 'hpv');
    final boyHpv = VaccineService.recommendationsFor(boy, const [])
        .firstWhere((item) => item.item.id == 'hpv');

    expect(girlHpv.status, VaccineStatus.noRecord);
    expect(boyHpv.status, VaccineStatus.notApplicable);
  });

  test('past doses without a saved record are no record, not missed', () {
    final profile = profileWithAge(years: 30, months: 0);
    final recommendations = VaccineService.recommendationsFor(profile, const []);

    final bcg = recommendations.firstWhere((item) => item.item.id == 'bcg');
    expect(bcg.status, VaccineStatus.noRecord);
    expect(VaccineService.statusLabel(bcg.status), 'No record on file');
    expect(
      VaccineService.statusExplanation(bcg.status).toLowerCase(),
      isNot(contains('overdue')),
    );
  });

  test('without a profile saved records stay recorded and no age state is invented',
      () {
    final record = VaccinationRecord(vaccineId: 'bcg', date: DateTime(2026, 1, 2));
    final recommendations =
        VaccineService.recommendationsWithoutAge(<VaccinationRecord>[record]);

    final bcg = recommendations.firstWhere((item) => item.item.id == 'bcg');
    final penta = recommendations.firstWhere((item) => item.item.id == 'penta1');
    expect(bcg.status, VaccineStatus.recorded);
    expect(bcg.record?.date, DateTime(2026, 1, 2));
    expect(penta.status, VaccineStatus.notApplicable);
  });

  test('age is derived from date of birth only', () {
    final profile = profileWithAge(years: 10, months: 0);
    expect(profile.age, 10);
    expect(profile.ageInMonths, closeTo(120, 1));
  });

  test('local vaccination repository saves and reloads records', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = VaccinationRepository(prefs: prefs);

    await repository.save(
      VaccinationRecord(vaccineId: 'bcg', date: DateTime(2026, 1, 2)),
    );
    final records = await repository.load();

    expect(records, hasLength(1));
    expect(records.single.vaccineId, 'bcg');
  });

  test('save updates an existing vaccine instead of duplicating it', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = VaccinationRepository(prefs: prefs);

    await repository.save(
      VaccinationRecord(vaccineId: 'bcg', date: DateTime(2026, 1, 2)),
    );
    await repository.save(
      VaccinationRecord(vaccineId: 'bcg', date: DateTime(2026, 2, 2)),
    );

    final records = await repository.load();
    expect(records, hasLength(1));
    expect(records.single.date, DateTime(2026, 2, 2));
  });
}
