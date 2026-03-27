# Sales Activity Tracker

A Flutter mobile app for salespeople to manage prospects and record daily sales interactions. All data is stored **100% locally** on the device using SQLite — no internet connection required.

## Features

- **Prospect Management** — Add, edit, search, and delete prospects. Tag each one with a relationship status (Hot / Warm / Cold / DKD).
- **Bulk CSV Import** — Import prospects from a CSV file. New enum values are auto-added to settings.
- **Activity Tracking** — Log every interaction with a prospect: action taken, remarks, conversation notes, next plan, and next engagement date.
- **Summary Screen** — Weekly (Sat–Fri) and monthly stats with an Overview, Actions breakdown (New vs Continued prospects), and a Details list.
- **Custom Settings** — CRUD dropdowns for Connection Type, Place, Current Status, Action Taken, and Next Plan of Action.
- **User Profile** — Name, role, and phone number stored locally; shown as a greeting on the home screen.
- **Backup & Restore** — Export the raw `.db` file via share sheet; import a `.db` file to restore.

## Tech Stack

| | |
|---|---|
| Framework | Flutter (Material 3) |
| Database | sqflite (SQLite) |
| State | Provider |
| File I/O | file_picker, share_plus |
| CSV | csv package |
| Persistence | shared_preferences (profile) |
| Other | intl, uuid, url_launcher |

## Getting Started

```bash
# Install dependencies
flutter pub get

# Run on iOS simulator (iPhone 16 Plus recommended)
flutter run

# Hot restart (re-runs seed data check)
# Press capital R in the terminal
```

## Project Structure

```
lib/
├── main.dart
├── models/          # Prospect, ProspectEvent, CustomEnum
├── database/        # DatabaseHelper singleton (SQLite, v3)
├── providers/       # ProspectProvider, EventProvider, EnumProvider, ProfileProvider
├── utils/           # IdGenerator, CsvImporter, SeedData
└── screens/         # All UI screens
```

## Database Schema

**prospects** — id, name, connection_type, place, current_status, relationship, instagram_link, linkedin_link, facebook_link, contact_number, created_at

**events** — event_id, prospect_id, last_action_taken, remarks, date_of_interaction, last_interaction_convo, next_plan_of_action, next_engagement_date

**custom_enums** — row_id, category_name, option_value

## CSV Import Format

Required columns: `name`, `connection_type`, `place`, `current_status`, `contact_number`

Optional columns: `instagram_link`, `linkedin_link`, `facebook_link`, `relationship`

The `relationship` column accepts: `Hot`, `Warm`, `Cold`, `DKD`

## Notes

- DB version 2 added `created_at`; version 3 added `relationship`. Both migrations use nullable `ALTER TABLE` columns to stay compatible with iOS SQLite (which rejects non-constant `DEFAULT` expressions in `ALTER TABLE`).
- The "New vs Continued" distinction in the Actions summary uses a `NOT EXISTS` subquery to detect the first-ever interaction with each prospect.
- The Sat–Fri week boundary is calculated as `daysSinceSat = (now.weekday + 1) % 7`.
