# Sales Activity Tracker — Project Specification & Build Log

## Overview
A Flutter mobile app for salespeople to manage prospects and record daily interactions. All data is stored 100% locally using SQLite — no cloud, no sync.

**Target platform:** iOS (iPhone 16 Plus simulator)
**Flutter:** latest stable
**State management:** Provider (ChangeNotifier)

---

## Tech Stack

| Concern | Package |
|---|---|
| Local database | `sqflite` + `path` |
| State management | `provider` |
| File picking | `file_picker` |
| CSV parsing | `csv` |
| Export / sharing | `share_plus` |
| Date formatting | `intl` |
| Unique IDs | `uuid` |
| Social links | `url_launcher` |
| User profile | `shared_preferences` |

---

## Data Models

### Table 1: prospects
| Column | Type | Notes |
|---|---|---|
| id | TEXT PK | `P-<uuid>` prefix; seed rows use `P-SEED####` |
| name | TEXT | Required |
| connection_type | TEXT | User-defined enum |
| place | TEXT | User-defined enum |
| current_status | TEXT | User-defined enum |
| relationship | TEXT | Fixed: Hot / Warm / Cold / DKD (nullable) |
| instagram_link | TEXT | Nullable |
| linkedin_link | TEXT | Nullable |
| facebook_link | TEXT | Nullable |
| contact_number | TEXT | Required |
| created_at | TEXT | ISO-8601; nullable for rows migrated from v1 |

### Table 2: events
| Column | Type | Notes |
|---|---|---|
| event_id | TEXT PK | `E-<uuid>` prefix |
| prospect_id | TEXT FK | Links to prospects.id |
| last_action_taken | TEXT | User-defined enum |
| remarks | TEXT | Free text |
| date_of_interaction | TEXT | ISO-8601 |
| last_interaction_convo | TEXT | Free text |
| next_plan_of_action | TEXT | User-defined enum |
| next_engagement_date | TEXT | ISO-8601 |

### Table 3: custom_enums
| Column | Type | Notes |
|---|---|---|
| row_id | INTEGER PK | Auto-increment |
| category_name | TEXT | e.g. `connection_type`, `place`, `current_status`, `last_action_taken`, `next_plan_of_action` |
| option_value | TEXT | The dropdown option |

Unique constraint: `(category_name, option_value)` — enforced via `ConflictAlgorithm.ignore`.

---

## Database Versioning

| Version | Change |
|---|---|
| 1 | Initial schema (prospects, events, custom_enums) |
| 2 | `ALTER TABLE prospects ADD COLUMN created_at TEXT` — nullable (iOS SQLite rejects non-constant defaults in ALTER TABLE) |
| 3 | `ALTER TABLE prospects ADD COLUMN relationship TEXT` — nullable |

---

## File / Module Map

```
lib/
├── main.dart                      # async main → SeedData.run() → MultiProvider → MainNavigation
├── models/
│   ├── prospect.dart              # Prospect model + relationshipOptions constant
│   ├── event.dart                 # ProspectEvent model
│   └── custom_enum.dart           # CustomEnum model
├── database/
│   └── database_helper.dart       # Singleton, v3, full CRUD, stats queries, autoAddEnumsFromProspects()
├── providers/
│   ├── prospect_provider.dart     # loadProspects, addProspect, updateProspect, deleteProspect,
│   │                              # searchProspects, bulkAddProspects → Map<String,int>
│   ├── event_provider.dart        # loadEvents, addEvent, updateEvent, deleteEvent
│   ├── enum_provider.dart         # EnumProvider with static categories + categoryLabels
│   └── profile_provider.dart      # shared_preferences: name / role / phone, initials getter
├── utils/
│   ├── id_generator.dart          # prospectId() → "P-<uuid>", eventId() → "E-<uuid>"
│   ├── csv_importer.dart          # importFromFile() — validates headers, supports relationship col
│   └── seed_data.dart             # SeedData.run() — 25 prospects + 100 events, Jan–Mar 2026
└── screens/
    ├── main_navigation.dart       # NavigationBar + IndexedStack (Prospects, Summary, Settings, Backup)
    ├── home_screen.dart           # Greeting, search bar, prospect count, card list with relationship badge
    ├── prospect_form_screen.dart  # Add/Edit form — all fields incl. relationship dropdown + CSV import
    ├── prospect_detail_screen.dart# Prospect info card (with relationship), event history
    ├── event_form_screen.dart     # Record/edit event with date pickers and enum dropdowns
    ├── settings_screen.dart       # My Profile card + Custom Dropdown Options section
    ├── backup_restore_screen.dart # Export via share_plus, import .db file
    └── weekly_stats_screen.dart   # Week/Month toggle, period selector, 3 tabs: Overview/Actions/Details
```

---

## Core Features

### 1. Prospect Management
- Manual add/edit via form with all fields
- Relationship field (Hot / Warm / Cold / DKD) — fixed 4-option dropdown, nullable
- Bulk import via CSV — required columns: `name, connection_type, place, current_status, contact_number`; optional: `instagram_link, linkedin_link, facebook_link, relationship`
- Auto-generate unique `P-<uuid>` ID for every new prospect
- Search by name on the home screen

### 2. Event / Activity Tracking
- "Record Event" button inside each prospect's detail screen
- Events linked to prospect via `prospect_id`
- Full CRUD on events

### 3. Custom Enum Settings
- 5 categories: Connection Type, Place, Current Status, Action Taken, Next Plan of Action
- CRUD per category on the Settings screen
- CSV import auto-adds new enum values from imported data (`autoAddEnumsFromProspects`)

### 4. User Profile
- Name, Role, Phone stored in shared_preferences
- Shown as greeting on home screen; avatar with initials in settings

### 5. Backup & Restore
- Export: shares the raw `.db` file via share_plus
- Import: picks a `.db` file with file_picker and overwrites the local database

### 6. Summary Screen (Weekly/Monthly Stats)
- **Period selector:** previous / next / date-picker navigation
- **Toggle:** Week (Sat–Fri) | Month
- **Overview tab:** total activities card, bar chart, day/week breakdown list
- **Actions tab:** per-action breakdown — each action shows total count, New vs Continued prospect split, percentage share of all activity
  - "New" = first-ever interaction with that prospect (NOT EXISTS subquery)
  - "Continued" = all subsequent interactions
- **Details tab:** new prospects added in period + all activities list

---

## Key Implementation Notes

### Week Calculation (Sat–Fri)
```dart
final daysSinceSat = (now.weekday + 1) % 7;
// weekday: Mon=1…Sun=7  →  Sat=0, Sun=1, Mon=2…Fri=6
```

### New vs Continued SQL
```sql
-- "New" interaction: no earlier event for this prospect exists
SELECT ... ,
  CASE WHEN NOT EXISTS (
    SELECT 1 FROM events e2
    WHERE e2.prospect_id = e.prospect_id
      AND e2.date_of_interaction < e.date_of_interaction
  ) THEN 1 ELSE 0 END AS is_new
FROM events e
WHERE date_of_interaction BETWEEN ? AND ?
```

### Monthly Bar Chart Bucketing
```dart
final weekNum = ((day.day - 1) ~/ 7) + 1; // groups days into Wk 1–5
```

### iOS ALTER TABLE Fix
SQLite on iOS rejects `ALTER TABLE … ADD COLUMN … DEFAULT (datetime('now'))`.
Migration uses `ADD COLUMN created_at TEXT` (nullable). `Prospect.fromMap` falls back to `DateTime.now()` when the value is null.

### bulkAddProspects Return Type
Returns `Map<String, int>` with keys `'prospects'` (rows inserted) and `'newEnums'` (new enum values added), so the UI can show a detailed snackbar after import.

---

## Seed Data
- 25 prospects with IDs `P-SEED0000` – `P-SEED0024`
- 100 events spread Jan–Mar 2026 (30% Jan, 35% Feb, 35% Mar)
- Inserted in a single SQLite transaction on first launch
- Guard: checks `SELECT COUNT(*) FROM prospects WHERE id LIKE 'P-SEED%'` — no-op if > 0
- Relationship values are randomly assigned from [Hot, Warm, Cold, DKD]

---

## Relationship Field
Fixed 4-option tag per prospect — not a user-configurable enum:

| Value | Meaning |
|---|---|
| Hot | High interest, close to converting |
| Warm | Engaged, needs nurturing |
| Cold | Low engagement |
| DKD | Don't Know Direction — status unclear |

Displayed as a coloured chip badge on the prospect card (home screen) and in the prospect detail card.
