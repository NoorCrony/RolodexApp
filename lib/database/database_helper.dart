import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/prospect.dart';
import '../models/event.dart';
import '../models/custom_enum.dart';
import '../models/weekly_plan.dart';

/// Singleton class that manages the SQLite database.
///
/// Handles table creation, CRUD operations for all three tables,
/// weekly stats queries, and backup/restore functionality.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get or create the database instance.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sales_tracker.db');
    return _database!;
  }

  /// Initialize the database file and create tables.
  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);

    return await openDatabase(
      path,
      version: 4, // v2: created_at  v3: relationship  v4: weekly_plans
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Create all three tables on first run (version 3+).
  Future<void> _createDB(Database db, int version) async {
    // Prospects table
    await db.execute('''
      CREATE TABLE prospects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        connection_type TEXT NOT NULL,
        place TEXT NOT NULL,
        current_status TEXT NOT NULL,
        relationship TEXT,
        instagram_link TEXT,
        linkedin_link TEXT,
        facebook_link TEXT,
        contact_number TEXT NOT NULL,
        created_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');

    // Events table with foreign key to prospects
    await db.execute('''
      CREATE TABLE events (
        event_id TEXT PRIMARY KEY,
        prospect_id TEXT NOT NULL,
        last_action_taken TEXT NOT NULL,
        remarks TEXT NOT NULL,
        date_of_interaction TEXT NOT NULL,
        last_interaction_convo TEXT NOT NULL,
        next_plan_of_action TEXT NOT NULL,
        next_engagement_date TEXT NOT NULL,
        FOREIGN KEY (prospect_id) REFERENCES prospects (id) ON DELETE CASCADE
      )
    ''');

    // Custom enums table for user-defined dropdown options
    await db.execute('''
      CREATE TABLE custom_enums (
        category_name TEXT NOT NULL,
        option_value TEXT NOT NULL,
        UNIQUE(category_name, option_value)
      )
    ''');

    // Weekly planner table
    await db.execute('''
      CREATE TABLE weekly_plans (
        id TEXT PRIMARY KEY,
        prospect_id TEXT NOT NULL,
        week_start TEXT NOT NULL,
        planned_action TEXT NOT NULL,
        is_done INTEGER NOT NULL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (prospect_id) REFERENCES prospects (id) ON DELETE CASCADE
      )
    ''');

    // Seed default enum values
    await _seedDefaults(db);
  }

  /// Migrate existing databases to newer schema versions.
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add created_at to existing prospects table.
      // iOS SQLite does not allow non-constant defaults in ALTER TABLE,
      // so we add the column as nullable — existing rows get NULL,
      // and Dart's fromMap falls back to DateTime.now() for those rows.
      await db.execute(
        'ALTER TABLE prospects ADD COLUMN created_at TEXT',
      );
    }
    if (oldVersion < 3) {
      // Add relationship column (nullable — existing rows default to NULL).
      await db.execute(
        'ALTER TABLE prospects ADD COLUMN relationship TEXT',
      );
    }
    if (oldVersion < 4) {
      // Add weekly planner table.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS weekly_plans (
          id TEXT PRIMARY KEY,
          prospect_id TEXT NOT NULL,
          week_start TEXT NOT NULL,
          planned_action TEXT NOT NULL,
          is_done INTEGER NOT NULL DEFAULT 0,
          notes TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (prospect_id) REFERENCES prospects (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  /// Insert default dropdown options so the app is usable out of the box.
  Future<void> _seedDefaults(Database db) async {
    final defaults = {
      'connection_type': ['Referral', 'Cold Call', 'Social Media', 'Event', 'Walk-in'],
      'place': ['Office', 'Coffee Shop', 'Online', 'Phone', 'Home Visit'],
      'current_status': ['Job', 'Business', 'Student', 'Unemployed'],
      'last_action_taken': ['Called', 'Messaged', 'Met In Person', 'Emailed', 'Presented'],
      'next_plan_of_action': ['Follow Up Call', 'Send Proposal', 'Schedule Meeting', 'Send Info', 'Close Deal'],
    };

    for (final entry in defaults.entries) {
      for (final value in entry.value) {
        await db.insert('custom_enums', {
          'category_name': entry.key,
          'option_value': value,
        });
      }
    }
  }

  // ──────────────────────────────────────────────
  // PROSPECT CRUD
  // ──────────────────────────────────────────────

  /// Insert a new prospect.
  Future<int> insertProspect(Prospect prospect) async {
    final db = await database;
    return await db.insert('prospects', prospect.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all prospects ordered by name.
  Future<List<Prospect>> getAllProspects() async {
    final db = await database;
    final maps = await db.query('prospects', orderBy: 'name ASC');
    return maps.map((map) => Prospect.fromMap(map)).toList();
  }

  /// Get a single prospect by ID.
  Future<Prospect?> getProspect(String id) async {
    final db = await database;
    final maps = await db.query('prospects', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Prospect.fromMap(maps.first);
  }

  /// Update an existing prospect.
  Future<int> updateProspect(Prospect prospect) async {
    final db = await database;
    return await db.update(
      'prospects',
      prospect.toMap(),
      where: 'id = ?',
      whereArgs: [prospect.id],
    );
  }

  /// Delete a prospect and all associated events (cascade).
  Future<int> deleteProspect(String id) async {
    final db = await database;
    // Delete events first (manual cascade for safety)
    await db.delete('events', where: 'prospect_id = ?', whereArgs: [id]);
    return await db.delete('prospects', where: 'id = ?', whereArgs: [id]);
  }

  /// Search prospects by name.
  Future<List<Prospect>> searchProspects(String query) async {
    final db = await database;
    final maps = await db.query(
      'prospects',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Prospect.fromMap(map)).toList();
  }

  // ──────────────────────────────────────────────
  // EVENT CRUD
  // ──────────────────────────────────────────────

  /// Insert a new event.
  Future<int> insertEvent(ProspectEvent event) async {
    final db = await database;
    return await db.insert('events', event.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all events for a specific prospect, newest first.
  Future<List<ProspectEvent>> getEventsForProspect(String prospectId) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'prospect_id = ?',
      whereArgs: [prospectId],
      orderBy: 'date_of_interaction DESC',
    );
    return maps.map((map) => ProspectEvent.fromMap(map)).toList();
  }

  /// Get the single most recent event for a prospect, or null if none exist.
  Future<ProspectEvent?> getLatestEventForProspect(String prospectId) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'prospect_id = ?',
      whereArgs: [prospectId],
      orderBy: 'date_of_interaction DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProspectEvent.fromMap(maps.first);
  }

  /// Update an existing event.
  Future<int> updateEvent(ProspectEvent event) async {
    final db = await database;
    return await db.update(
      'events',
      event.toMap(),
      where: 'event_id = ?',
      whereArgs: [event.eventId],
    );
  }

  /// Delete an event by ID.
  Future<int> deleteEvent(String eventId) async {
    final db = await database;
    return await db.delete('events', where: 'event_id = ?', whereArgs: [eventId]);
  }

  // ──────────────────────────────────────────────
  // WEEKLY STATS
  // ──────────────────────────────────────────────

  /// Count new prospects added between [from] (inclusive) and [to] (exclusive).
  Future<int> countNewProspects(DateTime from, DateTime to) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM prospects WHERE created_at >= ? AND created_at < ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Count events recorded between [from] and [to] by date_of_interaction.
  Future<int> countActivities(DateTime from, DateTime to) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM events WHERE date_of_interaction >= ? AND date_of_interaction < ?',
      [from.toIso8601String(), to.toIso8601String()],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  /// Get new prospects added between [from] and [to], newest first.
  Future<List<Prospect>> getNewProspects(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'prospects',
      where: 'created_at >= ? AND created_at < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'created_at DESC',
    );
    return maps.map((map) => Prospect.fromMap(map)).toList();
  }

  /// Get events recorded between [from] and [to], newest first.
  Future<List<ProspectEvent>> getActivities(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.query(
      'events',
      where: 'date_of_interaction >= ? AND date_of_interaction < ?',
      whereArgs: [from.toIso8601String(), to.toIso8601String()],
      orderBy: 'date_of_interaction DESC',
    );
    return maps.map((map) => ProspectEvent.fromMap(map)).toList();
  }

  /// Returns action breakdown for the week:
  /// a list of maps with keys: action, total, newCount.
  ///
  /// "new" = the prospect had NO events before this event's date,
  /// meaning this week was the very first time they were contacted.
  /// "continued" = total - newCount.
  Future<List<Map<String, dynamic>>> getActionBreakdown(
      DateTime from, DateTime to) async {
    final db = await database;
    final fromStr = from.toIso8601String();
    final toStr = to.toIso8601String();

    // Total events per action this week
    final totals = await db.rawQuery(
      'SELECT last_action_taken as action, COUNT(*) as total '
      'FROM events '
      'WHERE date_of_interaction >= ? AND date_of_interaction < ? '
      'GROUP BY last_action_taken '
      'ORDER BY total DESC',
      [fromStr, toStr],
    );

    // "New" events: events this week where the prospect has no earlier events
    // (i.e. this is the first time this prospect was ever contacted)
    final newCounts = await db.rawQuery(
      'SELECT e.last_action_taken as action, COUNT(*) as new_count '
      'FROM events e '
      'WHERE e.date_of_interaction >= ? AND e.date_of_interaction < ? '
      'AND NOT EXISTS ( '
      '  SELECT 1 FROM events e2 '
      '  WHERE e2.prospect_id = e.prospect_id '
      '  AND e2.date_of_interaction < e.date_of_interaction '
      ') '
      'GROUP BY e.last_action_taken',
      [fromStr, toStr],
    );

    // Build a lookup: action → newCount
    final newLookup = <String, int>{
      for (final m in newCounts)
        m['action'] as String: (m['new_count'] as int? ?? 0),
    };

    return totals.map((m) {
      final action = m['action'] as String;
      final total = m['total'] as int? ?? 0;
      final newCount = newLookup[action] ?? 0;
      return {
        'action': action,
        'total': total,
        'newCount': newCount,
        'continued': total - newCount,
      };
    }).toList();
  }

  /// Count activities per day within a week for the bar chart.
  /// Returns a map of ISO date string (yyyy-MM-dd) → count.
  Future<Map<String, int>> countActivitiesPerDay(DateTime from, DateTime to) async {
    final db = await database;
    final maps = await db.rawQuery(
      "SELECT substr(date_of_interaction, 1, 10) as day, COUNT(*) as count "
      "FROM events WHERE date_of_interaction >= ? AND date_of_interaction < ? "
      "GROUP BY day ORDER BY day",
      [from.toIso8601String(), to.toIso8601String()],
    );
    return {
      for (final m in maps) m['day'] as String: (m['count'] as int? ?? 0),
    };
  }

  /// Count activities per week within a month for the monthly bar chart.
  /// Returns a list of maps: [{label: 'Wk 1', count: N}, ...]
  Future<List<Map<String, dynamic>>> countActivitiesPerWeek(
      DateTime from, DateTime to) async {
    final db = await database;
    // Pull all daily counts then bucket into Mon-start ISO weeks
    final maps = await db.rawQuery(
      "SELECT substr(date_of_interaction, 1, 10) as day, COUNT(*) as count "
      "FROM events WHERE date_of_interaction >= ? AND date_of_interaction < ? "
      "GROUP BY day ORDER BY day",
      [from.toIso8601String(), to.toIso8601String()],
    );

    // Group by calendar week number within the month (week 1..5)
    final Map<int, int> weekBuckets = {};
    for (final m in maps) {
      final day = DateTime.parse(m['day'] as String);
      // Week index: 1-based, based on day-of-month
      final weekNum = ((day.day - 1) ~/ 7) + 1;
      weekBuckets[weekNum] = (weekBuckets[weekNum] ?? 0) + (m['count'] as int);
    }

    // Build ordered result for all weeks that fall in range
    final totalDays = to.difference(from).inDays;
    final totalWeeks = ((totalDays - 1) ~/ 7) + 1;
    return List.generate(totalWeeks.clamp(1, 5), (i) {
      return {'label': 'Wk ${i + 1}', 'count': weekBuckets[i + 1] ?? 0};
    });
  }

  // ──────────────────────────────────────────────
  // CUSTOM ENUM CRUD
  // ──────────────────────────────────────────────

  /// Auto-add any enum values found in the imported prospects that don't
  /// already exist. Uses INSERT OR IGNORE so existing values are untouched.
  /// Returns the number of new values added across all categories.
  Future<int> autoAddEnumsFromProspects(List<Prospect> prospects) async {
    final db = await database;

    // Collect unique non-empty values per category
    final toAdd = <String, Set<String>>{
      'connection_type': {},
      'place': {},
      'current_status': {},
    };
    for (final p in prospects) {
      if (p.connectionType.isNotEmpty) toAdd['connection_type']!.add(p.connectionType);
      if (p.place.isNotEmpty)          toAdd['place']!.add(p.place);
      if (p.currentStatus.isNotEmpty)  toAdd['current_status']!.add(p.currentStatus);
    }

    int added = 0;
    await db.transaction((txn) async {
      for (final entry in toAdd.entries) {
        for (final value in entry.value) {
          final rows = await txn.insert(
            'custom_enums',
            {'category_name': entry.key, 'option_value': value},
            conflictAlgorithm: ConflictAlgorithm.ignore, // skip duplicates
          );
          if (rows > 0) added++;
        }
      }
    });
    return added;
  }

  /// Get all options for a specific category.
  Future<List<String>> getEnumValues(String categoryName) async {
    final db = await database;
    final maps = await db.query(
      'custom_enums',
      where: 'category_name = ?',
      whereArgs: [categoryName],
      orderBy: 'option_value ASC',
    );
    return maps.map((m) => m['option_value'] as String).toList();
  }

  /// Get all custom enums grouped by category.
  Future<Map<String, List<String>>> getAllEnums() async {
    final db = await database;
    final maps = await db.query('custom_enums', orderBy: 'category_name, option_value');
    final result = <String, List<String>>{};
    for (final map in maps) {
      final category = map['category_name'] as String;
      final value = map['option_value'] as String;
      result.putIfAbsent(category, () => []).add(value);
    }
    return result;
  }

  /// Add a new enum option.
  Future<int> addEnumValue(String categoryName, String optionValue) async {
    final db = await database;
    return await db.insert('custom_enums', {
      'category_name': categoryName,
      'option_value': optionValue,
    });
  }

  /// Update an enum option value.
  Future<int> updateEnumValue(
      String categoryName, String oldValue, String newValue) async {
    final db = await database;
    return await db.update(
      'custom_enums',
      {'option_value': newValue},
      where: 'category_name = ? AND option_value = ?',
      whereArgs: [categoryName, oldValue],
    );
  }

  /// Delete an enum option.
  Future<int> deleteEnumValue(String categoryName, String optionValue) async {
    final db = await database;
    return await db.delete(
      'custom_enums',
      where: 'category_name = ? AND option_value = ?',
      whereArgs: [categoryName, optionValue],
    );
  }

  // ──────────────────────────────────────────────
  // BACKUP & RESTORE
  // ──────────────────────────────────────────────

  /// Get the path to the current database file.
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'sales_tracker.db');
  }

  /// Export the database file to a given directory.
  Future<File> exportDatabase(String exportDir) async {
    final dbPath = await getDatabasePath();
    final dbFile = File(dbPath);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final exportPath = join(exportDir, 'sales_tracker_backup_$timestamp.db');
    return await dbFile.copy(exportPath);
  }

  // ──────────────────────────────────────────────
  // WEEKLY PLAN CRUD
  // ──────────────────────────────────────────────

  Future<void> insertWeeklyPlan(WeeklyPlan plan) async {
    final db = await database;
    await db.insert('weekly_plans', plan.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<WeeklyPlan>> getWeeklyPlans(DateTime weekStart) async {
    final db = await database;
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final maps = await db.query(
      'weekly_plans',
      where: 'week_start = ?',
      whereArgs: [start.toIso8601String()],
      orderBy: 'created_at ASC',
    );
    return maps.map(WeeklyPlan.fromMap).toList();
  }

  Future<void> updateWeeklyPlan(WeeklyPlan plan) async {
    final db = await database;
    await db.update('weekly_plans', plan.toMap(),
        where: 'id = ?', whereArgs: [plan.id]);
  }

  Future<void> deleteWeeklyPlan(String id) async {
    final db = await database;
    await db.delete('weekly_plans', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns prospects whose latest nextEngagementDate falls within [weekStart, weekEnd].
  Future<List<SuggestedPlan>> getSuggestedPlans(
      DateTime weekStart, DateTime weekEnd) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT
        p.id           AS prospect_id,
        p.name         AS prospect_name,
        p.relationship AS relationship,
        e.next_plan_of_action AS planned_action,
        e.next_engagement_date AS next_date
      FROM events e
      JOIN prospects p ON p.id = e.prospect_id
      WHERE e.next_engagement_date >= ?
        AND e.next_engagement_date <= ?
      GROUP BY e.prospect_id
      HAVING e.next_engagement_date = MAX(e.next_engagement_date)
      ORDER BY e.next_engagement_date ASC
    ''', [weekStart.toIso8601String(), weekEnd.toIso8601String()]);

    return rows
        .map((r) => SuggestedPlan(
              prospectId: r['prospect_id'] as String,
              prospectName: r['prospect_name'] as String,
              relationship: r['relationship'] as String?,
              plannedAction: r['planned_action'] as String,
              nextEngagementDate:
                  DateTime.parse(r['next_date'] as String),
            ))
        .toList();
  }

  /// Restore the database from an imported .db file.
  Future<void> restoreDatabase(String importPath) async {
    // Close the current database
    final db = await database;
    await db.close();
    _database = null;

    // Overwrite the database file
    final dbPath = await getDatabasePath();
    final importFile = File(importPath);
    await importFile.copy(dbPath);

    // Re-open the database
    _database = await _initDB('sales_tracker.db');
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
