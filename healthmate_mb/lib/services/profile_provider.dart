import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import 'profile_repository.dart';

/// One local source of truth for the profile. Every screen reads from this
/// provider, so an edit made in Profile is immediately visible everywhere.
class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;

  UserProfile? _profile;
  bool _loading = true;
  bool _initialized = false;
  bool _setupSkipped = false;
  String? _storageError;

  ProfileProvider(this._repository);

  UserProfile? get profile => _profile;
  bool get loading => _loading;
  bool get initialized => _initialized;
  bool get setupSkipped => _setupSkipped;
  String? get storageError => _storageError;

  bool get hasProfile => _profile != null;
  bool get isComplete => _profile?.isComplete ?? false;
  bool get needsSetup => !isComplete && !_setupSkipped;

  Future<void> initialize() async {
    if (_initialized) return;
    _loading = true;
    notifyListeners();

    try {
      final migrated = await _repository.migrateLegacy();
      final loaded = await _repository.load();
      _profile = loaded ?? migrated;
      _setupSkipped = await _repository.loadSetupSkipped();
      _storageError = null;
    } catch (_) {
      _storageError =
          'Local storage is unavailable. Profile changes cannot be saved in this browser session.';
    }

    _initialized = true;
    _loading = false;
    notifyListeners();
  }

  /// Saves locally and returns whether the write actually succeeded. The
  /// in-memory copy is replaced only after the write, so the app never claims a
  /// change was saved when storage rejected it.
  Future<bool> save(UserProfile profile) async {
    final now = DateTime.now();
    final updated = profile.copyWith(
      createdAt: profile.createdAt ?? _profile?.createdAt ?? now,
      updatedAt: now,
    );

    try {
      final saved = await _repository.save(updated);
      if (!saved) {
        _storageError =
            'Local storage did not accept the change. Your previous saved copy may still be available.';
        notifyListeners();
        return false;
      }
      _profile = updated;
      _setupSkipped = false;
      _storageError = null;
      notifyListeners();
      return true;
    } catch (_) {
      _storageError =
          'Local storage is unavailable. This change will not survive a refresh.';
      notifyListeners();
      return false;
    }
  }

  Future<void> skipSetup() async {
    _setupSkipped = true;
    await _repository.setSetupSkipped(true);
    notifyListeners();
  }

  Future<void> clearLocalProfile() async {
    await _repository.clear();
    _profile = null;
    _setupSkipped = false;
    _storageError = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _profile = await _repository.load();
      _storageError = null;
    } catch (_) {
      _storageError = 'Local storage is unavailable.';
    }
    notifyListeners();
  }
}
