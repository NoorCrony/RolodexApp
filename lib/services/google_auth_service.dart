import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

/// Singleton wrapper around GoogleSignIn.
/// Requests only the Drive file scope (read/write files the app created).
class GoogleAuthService {
  GoogleAuthService._();

  static final _instance = GoogleSignIn(
    scopes: [
      'email',
      drive.DriveApi.driveFileScope,
    ],
  );

  static GoogleSignIn get instance => _instance;

  /// Returns the currently signed-in account, or null.
  static GoogleSignInAccount? get currentUser => _instance.currentUser;

  /// Triggers the interactive sign-in flow.
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _instance.signIn();
    } catch (e) {
      return null;
    }
  }

  /// Attempts to sign in silently (e.g. on app launch).
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      return await _instance.signInSilently();
    } catch (e) {
      return null;
    }
  }

  /// Signs the user out.
  static Future<void> signOut() async {
    await _instance.signOut();
  }

  /// Returns auth headers for the currently signed-in user.
  /// Throws if the user is not signed in.
  static Future<Map<String, String>> getAuthHeaders() async {
    final user = _instance.currentUser ?? await _instance.signInSilently();
    if (user == null) throw Exception('Not signed in to Google');
    return await user.authHeaders;
  }
}
