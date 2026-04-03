import 'dart:math';
import '../database/database_helper.dart';
import '../models/prospect.dart';
import '../models/event.dart';

/// Seeder utility — inserts 500 dummy prospects and 1500 dummy activities
/// spread across Nov 2025 – Apr 2026.
///
/// Call [SeedData.run] once from main(). It checks if data already exists
/// so it's safe to call on every launch without duplicating.
class SeedData {
  static final _rng = Random(42);

  static const _firstNames = [
    'Ali', 'Sara', 'Omar', 'Layla', 'Hassan', 'Nadia', 'Khalid', 'Rania',
    'Yousef', 'Hana', 'Tariq', 'Dina', 'Faisal', 'Mona', 'Karim', 'Lina',
    'Ahmad', 'Sana', 'Bilal', 'Maya', 'Ziad', 'Rana', 'Samir', 'Nour',
    'Walid', 'Fatima', 'Ramzi', 'Amira', 'Jad', 'Yasmine', 'Imad', 'Heba',
    'Mazen', 'Ola', 'Samer', 'Reem', 'Wissam', 'Ghada', 'Tarek', 'Amal',
    'Ibrahim', 'Sherine', 'Nasser', 'Hind', 'Marwan', 'Sahar', 'Rami', 'Iman',
    'Khaled', 'Salma',
  ];

  static const _lastNames = [
    'Al-Rashid', 'Mansour', 'Hassan', 'Ibrahim', 'Abdullah', 'Saleh',
    'Nasser', 'Khalil', 'Farouk', 'Aziz', 'Rahman', 'Karimi', 'Haddad',
    'Saad', 'Youssef', 'Barakat', 'Hamdan', 'Qasim', 'Nassar', 'Khoury',
    'Jaber', 'Fakhoury', 'Mubarak', 'Touma', 'Asmar', 'Bishara', 'Daher',
    'Rizk', 'Gemayel', 'Salam',
  ];

  static const _connectionTypes = [
    'Referral', 'Cold Call', 'Social Media', 'Event', 'Walk-in',
  ];

  static const _places = [
    'Office', 'Coffee Shop', 'Online', 'Phone', 'Home Visit',
  ];

  static const _statuses = ['Job', 'Business', 'Student', 'Unemployed'];

  static const _relationships = ['Hot', 'Warm', 'Cold', 'DKD'];

  static const _actions = [
    'Called', 'Messaged', 'Met In Person', 'Emailed', 'Presented',
  ];

  static const _nextPlans = [
    'Follow Up Call', 'Send Proposal', 'Schedule Meeting',
    'Send Info', 'Close Deal',
  ];

  static const _remarks = [
    'Interested, needs more info',
    'Requested a callback next week',
    'Seemed hesitant but open',
    'Very enthusiastic about the offer',
    'Asked for a written proposal',
    'Needs approval from partner',
    'Budget concerns raised',
    'Wants a demo session',
    'Confirmed interest, next step agreed',
    'Follow up after holiday',
    'Referred two more contacts',
    'Not available, left voicemail',
    'Positive response, scheduling meeting',
    'Already has a similar service',
    'Strong candidate, high priority',
  ];

  static const _convos = [
    'Discussed product features and pricing options.',
    'Reviewed previous proposal and answered questions.',
    'Introduced the full product lineup.',
    'Talked about current pain points and how we can help.',
    'Scheduled a demo for next week.',
    'Went through the comparison with competitors.',
    'Discussed timeline for a decision.',
    'Addressed objections about cost.',
    'Shared success stories from similar clients.',
    'Agreed on next steps and follow-up date.',
  ];

  // ── Instagram handle samples ────────────────────────────────────────────
  static const _igSuffixes = [
    '', '.official', '_real', '._', '.life', '_pro', '.daily', '_page',
  ];

  static String _igHandle(String name) {
    final clean = name.toLowerCase().replaceAll(' ', '.').replaceAll('-', '');
    final suffix = _igSuffixes[_rng.nextInt(_igSuffixes.length)];
    return 'https://instagram.com/$clean$suffix';
  }

  static String _liHandle(String name) {
    final clean = name.toLowerCase().replaceAll(' ', '-').replaceAll("'", '');
    return 'https://linkedin.com/in/$clean';
  }

  /// Run the seeder. No-op if any seeded prospects already exist.
  static Future<void> run() async {
    final db = await DatabaseHelper.instance.database;

    // Check if seed data already exists
    final check = await db.rawQuery(
      "SELECT COUNT(*) as c FROM prospects WHERE id LIKE 'P-SEED%'",
    );

    if ((check.first['c'] as int) > 0) {
      // Patch existing seeds that are missing social links
      await _patchSocialLinks(db);
      return;
    }

    // Date range: Jan 1 2026 → Mar 31 2026
    final rangeStart = DateTime(2026, 1, 1);
    final rangeEnd   = DateTime(2026, 3, 31, 23, 59, 59);
    final rangeDays  = rangeEnd.difference(rangeStart).inDays;

    // Build 25 prospect objects in memory
    final prospects = <Prospect>[];
    for (int i = 0; i < 25; i++) {
      final createdAt =
          rangeStart.add(Duration(days: _rng.nextInt(rangeDays + 1)));
      final name =
          '${_firstNames[_rng.nextInt(_firstNames.length)]} ${_lastNames[_rng.nextInt(_lastNames.length)]}';
      // ~80 % of seeds get Instagram, ~70 % get LinkedIn
      final hasIg = _rng.nextDouble() < 0.8;
      final hasLi = _rng.nextDouble() < 0.7;
      prospects.add(Prospect(
        id: 'P-SEED${i.toString().padLeft(4, '0')}',
        name: name,
        connectionType:
            _connectionTypes[_rng.nextInt(_connectionTypes.length)],
        place: _places[_rng.nextInt(_places.length)],
        currentStatus: _statuses[_rng.nextInt(_statuses.length)],
        relationship: _relationships[_rng.nextInt(_relationships.length)],
        contactNumber: '05${_rng.nextInt(90000000) + 10000000}',
        instagramLink: hasIg ? _igHandle(name) : null,
        linkedinLink:  hasLi ? _liHandle(name) : null,
        createdAt: createdAt,
      ));
    }

    // Build 100 event objects in memory spread across Jan–Mar 2026
    final monthWeights = {
      1: 0.30, // Jan 2026
      2: 0.35, // Feb 2026
      3: 0.35, // Mar 2026
    };
    final events = <ProspectEvent>[];
    int eventIndex = 0;
    for (final entry in monthWeights.entries) {
      final month = entry.key;
      final year  = 2026;
      final count = (100 * entry.value).round();
      final mStart = DateTime(year, month, 1);
      final mEnd   = DateTime(year, month + 1, 1);
      final mDays  = mEnd.difference(mStart).inDays;

      for (int j = 0; j < count && eventIndex < 100; j++, eventIndex++) {
        final prospect = prospects[_rng.nextInt(prospects.length)];
        final interactionDate = mStart.add(Duration(
          days: _rng.nextInt(mDays),
          hours: _rng.nextInt(9) + 8,
        ));
        events.add(ProspectEvent(
          eventId: 'E-SEED${eventIndex.toString().padLeft(5, '0')}',
          prospectId: prospect.id,
          lastActionTaken: _actions[_rng.nextInt(_actions.length)],
          remarks: _remarks[_rng.nextInt(_remarks.length)],
          dateOfInteraction: interactionDate,
          lastInteractionConvo: _convos[_rng.nextInt(_convos.length)],
          nextPlanOfAction: _nextPlans[_rng.nextInt(_nextPlans.length)],
          nextEngagementDate:
              interactionDate.add(Duration(days: _rng.nextInt(14) + 1)),
        ));
      }
    }

    // Insert everything in a single transaction — much faster than row-by-row
    await db.transaction((txn) async {
      for (final p in prospects) {
        await txn.insert('prospects', p.toMap());
      }
      for (final e in events) {
        await txn.insert('events', e.toMap());
      }
    });
  }

  /// Patch existing seeded prospects that are missing social links.
  static Future<void> _patchSocialLinks(dynamic db) async {
    final rows = await db.rawQuery(
      "SELECT id, name, instagram_link, linkedin_link FROM prospects WHERE id LIKE 'P-SEED%'",
    );
    for (final row in rows) {
      final id   = row['id'] as String;
      final name = row['name'] as String;
      final noIg = row['instagram_link'] == null;
      final noLi = row['linkedin_link'] == null;
      if (!noIg && !noLi) continue; // already has links

      final updates = <String, dynamic>{};
      if (noIg && _rng.nextDouble() < 0.8) updates['instagram_link'] = _igHandle(name);
      if (noLi && _rng.nextDouble() < 0.7) updates['linkedin_link']  = _liHandle(name);
      if (updates.isEmpty) continue;

      await db.update(
        'prospects',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }
}
