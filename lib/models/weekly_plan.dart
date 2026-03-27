/// A manually planned activity for a specific prospect in a given week.
class WeeklyPlan {
  final String id;
  final String prospectId;
  final DateTime weekStart;   // Always a Saturday
  final String plannedAction;
  final bool isDone;
  final String? notes;
  final DateTime createdAt;

  WeeklyPlan({
    required this.id,
    required this.prospectId,
    required this.weekStart,
    required this.plannedAction,
    this.isDone = false,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'prospect_id': prospectId,
        'week_start': weekStart.toIso8601String(),
        'planned_action': plannedAction,
        'is_done': isDone ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory WeeklyPlan.fromMap(Map<String, dynamic> m) => WeeklyPlan(
        id: m['id'] as String,
        prospectId: m['prospect_id'] as String,
        weekStart: DateTime.parse(m['week_start'] as String),
        plannedAction: m['planned_action'] as String,
        isDone: (m['is_done'] as int) == 1,
        notes: m['notes'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  WeeklyPlan copyWith({
    bool? isDone,
    String? plannedAction,
    String? notes,
  }) =>
      WeeklyPlan(
        id: id,
        prospectId: prospectId,
        weekStart: weekStart,
        plannedAction: plannedAction ?? this.plannedAction,
        isDone: isDone ?? this.isDone,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}

/// A prospect whose next engagement date falls within the current week
/// (auto-pulled from event records — not manually added).
class SuggestedPlan {
  final String prospectId;
  final String prospectName;
  final String? relationship;
  final String plannedAction;
  final DateTime nextEngagementDate;

  const SuggestedPlan({
    required this.prospectId,
    required this.prospectName,
    this.relationship,
    required this.plannedAction,
    required this.nextEngagementDate,
  });
}
