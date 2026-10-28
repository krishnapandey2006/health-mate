import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('without Firebase credentials the app starts in an explicit device-only state', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();

    await auth.init();

    expect(auth.isConfigured, isFalse);
    expect(auth.isSignedIn, isFalse);
    expect(auth.isDeviceMode, isFalse);
    expect(auth.initError, contains('Cloud accounts are not configured'));
  });

  test('device-only choice is persisted and restored on the next start', () async {
    SharedPreferences.setMockInitialValues({});
    final first = AuthService();
    await first.init();
    await first.continueOnDevice();

    expect(first.isDeviceMode, isTrue);
    expect(first.isSignedIn, isFalse);

    final second = AuthService();
    await second.init();
    expect(second.isDeviceMode, isTrue);
    expect(second.isConfigured, isFalse);
  });

  test('switching back to a cloud account clears device-only mode', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.init();
    await auth.continueOnDevice();
    await auth.useCloudAccount();

    expect(auth.isDeviceMode, isFalse);
  });

  test('signing out without a Firebase session is a safe no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final auth = AuthService();
    await auth.init();
    await auth.continueOnDevice();

    await auth.signOut();

    expect(auth.isSignedIn, isFalse);
    expect(auth.isDeviceMode, isTrue);
  });
}
