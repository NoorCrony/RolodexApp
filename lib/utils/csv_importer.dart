import 'dart:io';
import 'package:csv/csv.dart';
import '../models/prospect.dart';
import 'id_generator.dart';

/// Utility for importing prospects from a CSV file.
///
/// Expected CSV columns (header row required):
/// name, connection_type, place, current_status, contact_number,
/// instagram_link, linkedin_link, facebook_link
class CsvImporter {
  /// Parse a CSV file and return a list of Prospect objects.
  ///
  /// Returns the list of parsed prospects or throws an exception
  /// if the file format is invalid.
  static Future<List<Prospect>> importFromFile(String filePath) async {
    final file = File(filePath);
    final contents = await file.readAsString();
    final rows = const CsvToListConverter().convert(contents, eol: '\n');

    if (rows.isEmpty) {
      throw FormatException('CSV file is empty.');
    }

    // First row is the header
    final header = rows.first.map((e) => e.toString().trim().toLowerCase()).toList();

    // Validate required columns
    const required = ['name', 'connection_type', 'place', 'current_status', 'contact_number'];
    for (final col in required) {
      if (!header.contains(col)) {
        throw FormatException('Missing required column: $col');
      }
    }

    final prospects = <Prospect>[];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < header.length) continue; // Skip malformed rows

      final map = <String, String>{};
      for (int j = 0; j < header.length; j++) {
        map[header[j]] = row[j].toString().trim();
      }

      // Skip rows with empty name
      if (map['name']?.isEmpty ?? true) continue;

      // Validate relationship value if present
      final rawRel = map['relationship'];
      final relationship = (rawRel != null &&
              Prospect.relationshipOptions
                  .map((e) => e.toLowerCase())
                  .contains(rawRel.toLowerCase()))
          ? Prospect.relationshipOptions.firstWhere(
              (e) => e.toLowerCase() == rawRel.toLowerCase())
          : null;

      prospects.add(Prospect(
        id: IdGenerator.prospectId(),
        name: map['name']!,
        connectionType: map['connection_type'] ?? '',
        place: map['place'] ?? '',
        currentStatus: map['current_status'] ?? '',
        relationship: relationship,
        contactNumber: map['contact_number'] ?? '',
        instagramLink: map['instagram_link'],
        linkedinLink: map['linkedin_link'],
        facebookLink: map['facebook_link'],
      ));
    }

    return prospects;
  }
}
