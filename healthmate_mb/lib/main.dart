import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app/theme.dart';
import 'language_provider.dart';
import 'l10n/app_localizations.dart';
import 'screens/app_bootstrap.dart';
import 'services/app_settings_provider.dart';
import 'services/profile_provider.dart';
import 'services/profile_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final languageProvider = LanguageProvider();
  await languageProvider.init();

  final settingsProvider = AppSettingsProvider();
  await settingsProvider.load();

  final profileProvider = ProfileProvider(ProfileRepository());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: languageProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: profileProvider),
      ],
      child: const HealthmateApp(),
    ),
  );
}

class HealthmateApp extends StatelessWidget {
  const HealthmateApp({super.key});

  @override
  Widget build(BuildContext context) {
    final languageCode = context.watch<LanguageProvider>().languageCode;
    final settings = context.watch<AppSettingsProvider>();

    return MaterialApp(
      title: 'HealthMate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: Locale(languageCode),
      supportedLocales: AppLocalizations.supportedLanguageCodes
          .map((code) => Locale(code))
          .toList(growable: false),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        AppLocalizations.delegate,
      ],
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(settings.textScale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppBootstrap(),
    );
  }
}
