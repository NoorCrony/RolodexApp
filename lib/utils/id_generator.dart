import 'package:uuid/uuid.dart';

/// Utility for generating unique IDs for prospects and events.
class IdGenerator {
  static const _uuid = Uuid();

  /// Generate a unique prospect ID with a "P-" prefix.
  static String prospectId() => 'P-${_uuid.v4().substring(0, 8).toUpperCase()}';

  /// Generate a unique event ID with an "E-" prefix.
  static String eventId() => 'E-${_uuid.v4().substring(0, 8).toUpperCase()}';
}
