import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/prospect.dart';

/// Provider that manages prospect state and database operations.
class ProspectProvider with ChangeNotifier {
  List<Prospect> _prospects = [];
  bool _isLoading = false;

  List<Prospect> get prospects => _prospects;
  bool get isLoading => _isLoading;

  /// Load all prospects from the database.
  Future<void> loadProspects() async {
    _isLoading = true;
    notifyListeners();

    _prospects = await DatabaseHelper.instance.getAllProspects();

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new prospect.
  Future<void> addProspect(Prospect prospect) async {
    await DatabaseHelper.instance.insertProspect(prospect);
    await loadProspects();
  }

  /// Update an existing prospect.
  Future<void> updateProspect(Prospect prospect) async {
    await DatabaseHelper.instance.updateProspect(prospect);
    await loadProspects();
  }

  /// Delete a prospect by ID.
  Future<void> deleteProspect(String id) async {
    await DatabaseHelper.instance.deleteProspect(id);
    await loadProspects();
  }

  /// Search prospects by name.
  Future<void> searchProspects(String query) async {
    if (query.isEmpty) {
      await loadProspects();
      return;
    }
    _prospects = await DatabaseHelper.instance.searchProspects(query);
    notifyListeners();
  }

  /// Bulk insert prospects (from CSV import).
  /// Also auto-adds any new enum values found in the imported data.
  /// Returns a map with 'prospects' and 'newEnums' counts.
  Future<Map<String, int>> bulkAddProspects(List<Prospect> newProspects) async {
    // Auto-add any new enum values found in the CSV first
    final newEnums =
        await DatabaseHelper.instance.autoAddEnumsFromProspects(newProspects);

    // Insert all prospects in one transaction
    final db = await DatabaseHelper.instance.database;
    await db.transaction((txn) async {
      for (final p in newProspects) {
        await txn.insert('prospects', p.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    await loadProspects();
    return {'prospects': newProspects.length, 'newEnums': newEnums};
  }
}
