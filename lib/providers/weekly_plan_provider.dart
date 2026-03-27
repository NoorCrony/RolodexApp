import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/weekly_plan.dart';

class WeeklyPlanProvider extends ChangeNotifier {
  List<WeeklyPlan> _plans = [];
  List<SuggestedPlan> _suggested = [];
  bool _isLoading = false;
  DateTime _weekStart = currentWeekSat();

  List<WeeklyPlan> get plans => _plans;
  List<SuggestedPlan> get suggested => _suggested;
  bool get isLoading => _isLoading;
  DateTime get weekStart => _weekStart;
  DateTime get weekEnd =>
      _weekStart.add(const Duration(days: 6, hours: 23, minutes: 59));

  int get totalPlanned => _plans.length + _suggested.length;
  int get totalDone => _plans.where((p) => p.isDone).length;

  /// Saturday of the current week (Sat–Fri calendar).
  static DateTime currentWeekSat() {
    final now = DateTime.now();
    // weekday: Mon=1 … Sun=7.  We want Sat=0 offset.
    final daysSinceSat = (now.weekday + 1) % 7;
    final sat = now.subtract(Duration(days: daysSinceSat));
    return DateTime(sat.year, sat.month, sat.day);
  }

  void goToPreviousWeek() {
    _weekStart = _weekStart.subtract(const Duration(days: 7));
    load();
  }

  void goToNextWeek() {
    _weekStart = _weekStart.add(const Duration(days: 7));
    load();
  }

  void jumpToWeek(DateTime saturday) {
    _weekStart = DateTime(saturday.year, saturday.month, saturday.day);
    load();
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();

    _plans     = await DatabaseHelper.instance.getWeeklyPlans(_weekStart);
    _suggested = await DatabaseHelper.instance.getSuggestedPlans(
        _weekStart, weekEnd);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addPlan({
    required String prospectId,
    required String plannedAction,
    String? notes,
  }) async {
    final plan = WeeklyPlan(
      id: const Uuid().v4(),
      prospectId: prospectId,
      weekStart: _weekStart,
      plannedAction: plannedAction,
      notes: notes,
    );
    await DatabaseHelper.instance.insertWeeklyPlan(plan);
    await load();
  }

  Future<void> toggleDone(WeeklyPlan plan) async {
    final updated = plan.copyWith(isDone: !plan.isDone);
    await DatabaseHelper.instance.updateWeeklyPlan(updated);
    await load();
  }

  Future<void> deletePlan(String id) async {
    await DatabaseHelper.instance.deleteWeeklyPlan(id);
    await load();
  }

  /// Returns true if a prospect is already in this week's manual plan.
  bool isAlreadyPlanned(String prospectId) =>
      _plans.any((p) => p.prospectId == prospectId);
}
