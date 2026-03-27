import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../database/database_helper.dart';
import '../providers/prospect_provider.dart';
import '../providers/enum_provider.dart';

/// Screen for exporting and importing the SQLite database backup.
class BackupRestoreScreen extends StatelessWidget {
  const BackupRestoreScreen({super.key});

  /// Export the database and share it via the system share sheet.
  Future<void> _exportBackup(BuildContext context) async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();

      await Share.shareXFiles(
        [XFile(dbPath)],
        subject: 'Sales Tracker Backup',
        text: 'Sales Activity Tracker database backup',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup shared successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Pick a .db file and restore it.
  Future<void> _importBackup(BuildContext context) async {
    // Confirm with the user first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace ALL current data with the backup file. '
          'This action cannot be undone. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        // Users should pick a .db file
      );

      if (result == null || result.files.single.path == null) return;

      final filePath = result.files.single.path!;

      // Validate it looks like a .db file
      if (!filePath.endsWith('.db')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a valid .db backup file.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await DatabaseHelper.instance.restoreDatabase(filePath);

      // Reload all providers after restore
      if (context.mounted) {
        await context.read<ProspectProvider>().loadProspects();
        await context.read<EnumProvider>().loadEnums();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored successfully!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Export section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.cloud_upload, size: 48, color: Colors.blue[400]),
                    const SizedBox(height: 12),
                    const Text(
                      'Export Backup',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Share your database file via email, cloud storage, or any other app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => _exportBackup(context),
                      icon: const Icon(Icons.share),
                      label: const Text('Export & Share'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Import section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(Icons.cloud_download, size: 48, color: Colors.orange[400]),
                    const SizedBox(height: 12),
                    const Text(
                      'Restore Backup',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Import a previously exported .db file to restore all your data.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => _importBackup(context),
                      icon: const Icon(Icons.file_open),
                      label: const Text('Select Backup File'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Warning note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Restoring a backup will replace all current data. Make sure to export first!',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
