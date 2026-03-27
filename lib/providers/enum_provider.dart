import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';

/// Provider that manages custom enum values for dropdown fields.
class EnumProvider with ChangeNotifier {
  Map<String, List<String>> _enums = {};
  bool _isLoading = false;

  Map<String, List<String>> get enums => _enums;
  bool get isLoading => _isLoading;

  /// All configurable enum categories.
  static const List<String> categories = [
    'connection_type',
    'place',
    'current_status',
    'last_action_taken',
    'next_plan_of_action',
  ];

  /// Human-readable labels for each category.
  static const Map<String, String> categoryLabels = {
    'connection_type': 'Connection Type',
    'place': 'Place',
    'current_status': 'Current Status',
    'last_action_taken': 'Last Action Taken',
    'next_plan_of_action': 'Next Plan of Action',
  };

  /// Load all enums from the database.
  Future<void> loadEnums() async {
    _isLoading = true;
    notifyListeners();

    _enums = await DatabaseHelper.instance.getAllEnums();

    _isLoading = false;
    notifyListeners();
  }

  /// Get values for a specific category.
  List<String> getValues(String category) {
    return _enums[category] ?? [];
  }

  /// Add a new option to a category.
  Future<void> addValue(String category, String value) async {
    await DatabaseHelper.instance.addEnumValue(category, value);
    await loadEnums();
  }

  /// Update an option value.
  Future<void> updateValue(String category, String oldValue, String newValue) async {
    await DatabaseHelper.instance.updateEnumValue(category, oldValue, newValue);
    await loadEnums();
  }

  /// Delete an option from a category.
  Future<void> deleteValue(String category, String value) async {
    await DatabaseHelper.instance.deleteEnumValue(category, value);
    await loadEnums();
  }
}
