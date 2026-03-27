/// Model class representing a user-defined dropdown option.
///
/// Used for fields like connection_type, place, last_action_taken, etc.
/// Users can CRUD these values in the Settings screen.
class CustomEnum {
  final int? rowId; // SQLite rowid for updates/deletes
  final String categoryName;
  final String optionValue;

  CustomEnum({
    this.rowId,
    required this.categoryName,
    required this.optionValue,
  });

  /// Convert to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'category_name': categoryName,
      'option_value': optionValue,
    };
  }

  /// Create from a database Map.
  factory CustomEnum.fromMap(Map<String, dynamic> map) {
    return CustomEnum(
      rowId: map['rowid'] as int?,
      categoryName: map['category_name'] as String,
      optionValue: map['option_value'] as String,
    );
  }
}
