import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../services/google_auth_service.dart';
import '../services/google_drive_backup_service.dart';

/// Task identifier used by Workmanager for the daily Drive backup.
const kDailyBackupTask = 'rolodex.dailyBackup';

/// Called by Workmanager in the background (must be a top-level function).
@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kDailyBackupTask) {
      try {
        // Re-authenticate silently in the background isolate
        final user = await GoogleAuthService.signInSilently();
        if (user == null) return Future.value(false);

        await GoogleDriveBackupService.backup();

        // Persist the backup time for the UI to read next time app opens
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          AuthProvider._kLastBackupKey,
          DateTime.now().toIso8601String(),
        );
        return Future.value(true);
      } catch (_) {
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

/// Manages Google sign-in state and Drive backup scheduling.
class AuthProvider extends ChangeNotifier {
  static const _kLastBackupKey = 'google_backup_last_at';

  GoogleSignInAccount? _currentUser;
  bool _isLoading = false;
  bool _isBackingUp = false;
  DateTime? _lastBackupAt;

  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  bool get isLoading => _isLoading;
  bool get isBackingUp => _isBackingUp;
  DateTime? get lastBackupAt => _lastBackupAt;

  /// Call once at startup to restore session silently.
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    // Try silent sign-in (restores previous session without UI)
    _currentUser = await GoogleAuthService.signInSilently();

    // Load persisted last-backup timestamp
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kLastBackupKey);
    if (stored != null) _lastBackupAt = DateTime.tryParse(stored);

    _isLoading = false;
    notifyListeners();
  }

  /// Launches the interactive Google sign-in flow.
  Future<bool> signIn() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await GoogleAuthService.signIn();
      if (_currentUser != null) {
        // Schedule the 6 AM daily backup now that we have credentials
        try {
          await _scheduleDailyBackup();
        } catch (_) {
          // Workmanager may not be available — sign-in still succeeds
        }
      }
    } catch (_) {
      _currentUser = null;
    }

    _isLoading = false;
    notifyListeners();
    return _currentUser != null;
  }

  /// Signs out and cancels the scheduled backup task.
  Future<void> signOut() async {
    await GoogleAuthService.signOut();
    await Workmanager().cancelByUniqueName(kDailyBackupTask);
    _currentUser = null;
    notifyListeners();
  }

  /// Triggers an immediate Drive backup and updates the last-backup time.
  Future<void> backupNow() async {
    if (!isSignedIn) return;
    _isBackingUp = true;
    notifyListeners();

    try {
      await GoogleDriveBackupService.backup();
      _lastBackupAt = DateTime.now();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastBackupKey, _lastBackupAt!.toIso8601String());
    } finally {
      _isBackingUp = false;
      notifyListeners();
    }
  }

  // ── Scheduling ────────────────────────────────────────────────────────────

  /// Registers a daily Workmanager periodic task with an initial delay
  /// calculated so the first run lands at (approximately) 06:00 local time.
  Future<void> _scheduleDailyBackup() async {
    final now     = DateTime.now();
    final next6am = DateTime(now.year, now.month, now.day, 6, 0, 0);
    final target  = now.isBefore(next6am) ? next6am : next6am.add(const Duration(days: 1));
    final delay   = target.difference(now);

    await Workmanager().registerPeriodicTask(
      kDailyBackupTask,
      kDailyBackupTask,
      frequency: const Duration(hours: 24),
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
  }
}
