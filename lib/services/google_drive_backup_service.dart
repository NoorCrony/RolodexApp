import 'dart:io' as dart_io;
import 'package:http/http.dart' as http;
import 'package:googleapis/drive/v3.dart' as drive;
import '../database/database_helper.dart';
import 'google_auth_service.dart';

/// Uploads / restores the SQLite database from Google Drive.
///
/// Files are stored inside a dedicated "Rolodex Backups" folder in the
/// user's Drive so they stay together and don't clutter the root.
class GoogleDriveBackupService {
  GoogleDriveBackupService._();

  static const _backupFileName = 'rolodex_backup.db';
  static const _folderName    = 'Rolodex Backups';

  // ── Auth client ──────────────────────────────────────────────────────────

  /// Creates an HTTP client that attaches the Google auth headers.
  static Future<_AuthenticatedClient> _buildClient() async {
    final headers = await GoogleAuthService.getAuthHeaders();
    return _AuthenticatedClient(headers);
  }

  // ── Folder helpers ────────────────────────────────────────────────────────

  /// Returns the Drive folder ID for "Rolodex Backups", creating it if needed.
  static Future<String> _getOrCreateFolder(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name='$_folderName' "
          "and mimeType='application/vnd.google-apps.folder' "
          "and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id!;
    }

    // Folder does not exist yet — create it
    final folder = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(folder, $fields: 'id');
    return created.id!;
  }

  /// Returns the Drive file ID of the existing backup, or null.
  static Future<String?> _findBackupFile(
      drive.DriveApi api, String folderId) async {
    final result = await api.files.list(
      q: "name='$_backupFileName' "
          "and '$folderId' in parents "
          "and trashed=false",
      spaces: 'drive',
      $fields: 'files(id,name)',
    );
    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id;
    }
    return null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Uploads the local SQLite database to Google Drive.
  /// Creates or overwrites the backup file inside "Rolodex Backups".
  static Future<void> backup() async {
    final client = await _buildClient();
    final api     = drive.DriveApi(client);

    final dbPath   = await DatabaseHelper.instance.getDatabasePath();
    final dbFile   = dart_io.File(dbPath);
    final fileSize = await dbFile.length();

    final folderId  = await _getOrCreateFolder(api);
    final existingId = await _findBackupFile(api, folderId);

    final media = drive.Media(
      dbFile.openRead(),
      fileSize,
      contentType: 'application/octet-stream',
    );

    if (existingId != null) {
      // Overwrite the existing backup
      await api.files.update(
        drive.File(),
        existingId,
        uploadMedia: media,
        $fields: 'id',
      );
    } else {
      // Upload for the first time
      final meta = drive.File()
        ..name    = _backupFileName
        ..parents = [folderId];
      await api.files.create(meta, uploadMedia: media, $fields: 'id');
    }

    client.close();
  }
}

// ── Internal authenticated HTTP client ────────────────────────────────────────

class _AuthenticatedClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _inner = http.Client();

  _AuthenticatedClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}
