/// Model class representing an interaction event with a prospect.
class ProspectEvent {
  final String eventId;
  final String prospectId;
  final String lastActionTaken;
  final String remarks;
  final DateTime dateOfInteraction;
  final String lastInteractionConvo;
  final String nextPlanOfAction;
  final DateTime nextEngagementDate;

  ProspectEvent({
    required this.eventId,
    required this.prospectId,
    required this.lastActionTaken,
    required this.remarks,
    required this.dateOfInteraction,
    required this.lastInteractionConvo,
    required this.nextPlanOfAction,
    required this.nextEngagementDate,
  });

  /// Convert an Event to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'prospect_id': prospectId,
      'last_action_taken': lastActionTaken,
      'remarks': remarks,
      'date_of_interaction': dateOfInteraction.toIso8601String(),
      'last_interaction_convo': lastInteractionConvo,
      'next_plan_of_action': nextPlanOfAction,
      'next_engagement_date': nextEngagementDate.toIso8601String(),
    };
  }

  /// Create an Event from a database Map.
  factory ProspectEvent.fromMap(Map<String, dynamic> map) {
    return ProspectEvent(
      eventId: map['event_id'] as String,
      prospectId: map['prospect_id'] as String,
      lastActionTaken: map['last_action_taken'] as String,
      remarks: map['remarks'] as String,
      dateOfInteraction: DateTime.parse(map['date_of_interaction'] as String),
      lastInteractionConvo: map['last_interaction_convo'] as String,
      nextPlanOfAction: map['next_plan_of_action'] as String,
      nextEngagementDate: DateTime.parse(map['next_engagement_date'] as String),
    );
  }

  /// Create a copy with updated fields.
  ProspectEvent copyWith({
    String? eventId,
    String? prospectId,
    String? lastActionTaken,
    String? remarks,
    DateTime? dateOfInteraction,
    String? lastInteractionConvo,
    String? nextPlanOfAction,
    DateTime? nextEngagementDate,
  }) {
    return ProspectEvent(
      eventId: eventId ?? this.eventId,
      prospectId: prospectId ?? this.prospectId,
      lastActionTaken: lastActionTaken ?? this.lastActionTaken,
      remarks: remarks ?? this.remarks,
      dateOfInteraction: dateOfInteraction ?? this.dateOfInteraction,
      lastInteractionConvo: lastInteractionConvo ?? this.lastInteractionConvo,
      nextPlanOfAction: nextPlanOfAction ?? this.nextPlanOfAction,
      nextEngagementDate: nextEngagementDate ?? this.nextEngagementDate,
    );
  }
}
