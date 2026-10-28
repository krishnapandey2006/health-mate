import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/theme.dart';
import '../services/profile_provider.dart';
import 'main_scaffold.dart';
import 'profile_setup_screen.dart';

/// Decides between local profile setup and the dashboard.
///
/// There is no account or sign-in step. Users can create a local profile or
/// choose to explore the public parts of the app without one.
class AppGate extends StatelessWidget {
  const AppGate({super.key});

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    if (profileProvider.loading) {
      return const _GateLoading();
    }

    if (profileProvider.needsSetup) {
      return const ProfileSetupScreen();
    }

    return const MainScaffold();
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.mintBackground,
      body: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.6),
        ),
      ),
    );
  }
}
