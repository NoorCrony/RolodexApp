import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/event.dart';

/// Provider that manages event state and database operations.
class EventProvider with ChangeNotifier {
  List<ProspectEvent> _events = [];
  bool _isLoading = false;

  List<ProspectEvent> get events => _events;
  bool get isLoading => _isLoading;

  /// Load all events for a specific prospect.
  Future<void> loadEvents(String prospectId) async {
    _isLoading = true;
    notifyListeners();

    _events = await DatabaseHelper.instance.getEventsForProspect(prospectId);

    _isLoading = false;
    notifyListeners();
  }

  /// Add a new event.
  Future<void> addEvent(ProspectEvent event) async {
    await DatabaseHelper.instance.insertEvent(event);
    await loadEvents(event.prospectId);
  }

  /// Update an existing event.
  Future<void> updateEvent(ProspectEvent event) async {
    await DatabaseHelper.instance.updateEvent(event);
    await loadEvents(event.prospectId);
  }

  /// Delete an event.
  Future<void> deleteEvent(String eventId, String prospectId) async {
    await DatabaseHelper.instance.deleteEvent(eventId);
    await loadEvents(prospectId);
  }
}
