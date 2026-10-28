import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:healthmate_mb/language_provider.dart';
import 'package:healthmate_mb/main.dart';
import 'package:healthmate_mb/services/app_settings_provider.dart';
import 'package:healthmate_mb/services/auth_service.dart';
import 'package:healthmate_mb/services/profile_provider.dart';
import 'package:healthmate_mb/services/profile_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('unconfigured build shows the truthful device-only auth screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final language = LanguageProvider();
    await language.init();
    final settings = AppSettingsProvider();
    await settings.load();
    final auth = AuthService();
    final profile = ProfileProvider(ProfileRepository(), auth);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: profile),
        ],
        child: const HealthmateApp(),
      ),
    );

    // AppBootstrap restores the session and profile asynchronously.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Use HealthMate on this device'), findsOneWidget);
    expect(find.text('Continue on this device'), findsOneWidget);
    expect(find.textContaining('does not create a cloud account'), findsOneWidget);
  });

  testWidgets('language selector updates the auth screen copy', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final language = LanguageProvider();
    await language.init();
    final settings = AppSettingsProvider();
    await settings.load();
    final auth = AuthService();
    final profile = ProfileProvider(ProfileRepository(), auth);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: language),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: profile),
        ],
        child: const HealthmateApp(),
      ),
    );

    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    await language.setLanguage('hi');
    await tester.pumpAndSettle();

    expect(find.text('फिर से स्वागत है'), findsOneWidget);
  });
}
