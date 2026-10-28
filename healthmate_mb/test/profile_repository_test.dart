import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/user_profile.dart';
import 'package:healthmate_mb/services/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCloudStore implements ProfileCloudStore {
  final Map<String, Map<String, dynamic>> data = {};
  bool available = true;
  bool failWrites = false;

  @override
  bool get isAvailable => available;

  @override
  Future<Map<String, dynamic>?> read(String uid) async => data[uid];

  @override
  Future<void> write(String uid, Map<String, dynamic> value) async {
    if (failWrites) throw StateError('offline');
    data[uid] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final profile = UserProfile(
    firstName: 'Asha',
    lastName: 'Patil',
    phone: '9876543210',
    dateOfBirth: DateTime(1992, 8, 15),
    gender: 'female',
    state: 'Maharashtra',
    languageCode: 'mr',
  );

  test('device profile saves and reloads from the local store', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repository = ProfileRepository(cloud: _FakeCloudStore(), prefs: prefs);

    await repository.saveLocal(null, profile);
    final loaded = await repository.loadLocal(null);

    expect(loaded?.firstName, 'Asha');
    expect(loaded?.state, 'Maharashtra');
    expect(loaded?.age, profile.age);
  });

  test('signed-in profile writes to cloud and clears pending sync', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cloud = _FakeCloudStore();
    final repository = ProfileRepository(cloud: cloud, prefs: prefs);

    final result = await repository.save('user-a', profile);

    expect(result.cloudSaved, isTrue);
    expect(cloud.data['user-a']?['firstName'], 'Asha');
    final local = await repository.loadLocal('user-a');
    expect(local?.pendingSync, isFalse);
  });

  test('failed cloud write keeps a truthful local copy', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cloud = _FakeCloudStore()..failWrites = true;
    final repository = ProfileRepository(cloud: cloud, prefs: prefs);

    final result = await repository.save('user-a', profile);

    expect(result.cloudSaved, isFalse);
    expect(result.error, contains('Could not reach the cloud'));
    final local = await repository.loadLocal('user-a');
    expect(local?.firstName, 'Asha');
    expect(local?.pendingSync, isTrue);
  });

  test('legacy split profile keys migrate into one profile', () async {
    SharedPreferences.setMockInitialValues({
      'first_name': 'Ravi',
      'last_name': 'Kumar',
      'user_phone': '9999999999',
      'user_dob': '1988-03-04',
      'user_gender': 'male',
      'user_state': 'Tamil Nadu',
      'language_code': 'ta',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = ProfileRepository(cloud: _FakeCloudStore(), prefs: prefs);

    final migrated = await repository.migrateLegacy();
    final loaded = await repository.loadLocal(null);

    expect(migrated?.firstName, 'Ravi');
    expect(migrated?.lastName, 'Kumar');
    expect(migrated?.dateOfBirth, DateTime(1988, 3, 4));
    expect(loaded?.phone, '9999999999');
    expect(loaded?.languageCode, 'ta');
  });

  test('legacy user_name is split without creating a duplicate age field', () async {
    SharedPreferences.setMockInitialValues({
      'user_name': 'Meera Joshi',
      'user_phone': '9888888888',
      'user_dob': '1995-06-10',
    });
    final prefs = await SharedPreferences.getInstance();
    final repository = ProfileRepository(cloud: _FakeCloudStore(), prefs: prefs);

    final migrated = await repository.migrateLegacy();

    expect(migrated?.firstName, 'Meera');
    expect(migrated?.lastName, 'Joshi');
    expect(migrated?.age, isNotNull);
  });

  test('cloud profile is restored over the local cache', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final cloud = _FakeCloudStore()
      ..data['user-a'] = {
        'firstName': 'Cloud',
        'lastName': 'User',
        'phone': '9000000000',
        'dateOfBirth': '1990-01-01T00:00:00.000',
        'gender': 'female',
        'state': 'Delhi',
        'languageCode': 'hi',
      };
    final repository = ProfileRepository(cloud: cloud, prefs: prefs);

    final result = await repository.load('user-a');

    expect(result.source, ProfileSource.cloud);
    expect(result.profile?.firstName, 'Cloud');
    expect((await repository.loadLocal('user-a'))?.firstName, 'Cloud');
  });
}
