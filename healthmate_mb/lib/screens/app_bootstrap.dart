import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../services/profile_provider.dart';
import '../widgets/app_widgets.dart';
import 'app_gate.dart';
import 'splash_screen.dart';

/// Initializes the local profile once, then hands control to [AppGate].
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  String? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_started) return;
    _started = true;
    if (mounted) setState(() => _error = null);

    try {
      if (!mounted) return;
      await context.read<ProfileProvider>().initialize();
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error =
            'HealthMate could not finish starting. Refresh the page and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const AppGate();
    if (_error != null) {
      final l10n = AppLocalizations.of(context);
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 64),
                    const SizedBox(height: 24),
                    Text(
                      l10n.t('startup_error_title'),
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        _started = false;
                        _initialize();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(l10n.t('retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return const SplashScreen();
  }
}
