/// Model class representing a sales prospect.
class Prospect {
  final String id;
  final String name;
  final String connectionType;
  final String place;
  final String currentStatus;
  final String? relationship; // Hot | DKD | Warm | Cold
  final String? instagramLink;
  final String? linkedinLink;
  final String? facebookLink;
  final String contactNumber;
  final DateTime createdAt;

  Prospect({
    required this.id,
    required this.name,
    required this.connectionType,
    required this.place,
    required this.currentStatus,
    this.relationship,
    this.instagramLink,
    this.linkedinLink,
    this.facebookLink,
    required this.contactNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// The four fixed relationship tags.
  static const List<String> relationshipOptions = ['Hot', 'Warm', 'Cold', 'DKD'];

  /// Convert a Prospect to a Map for database insertion.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'connection_type': connectionType,
      'place': place,
      'current_status': currentStatus,
      'relationship': relationship,
      'instagram_link': instagramLink,
      'linkedin_link': linkedinLink,
      'facebook_link': facebookLink,
      'contact_number': contactNumber,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create a Prospect from a database Map.
  factory Prospect.fromMap(Map<String, dynamic> map) {
    return Prospect(
      id: map['id'] as String,
      name: map['name'] as String,
      connectionType: map['connection_type'] as String,
      place: map['place'] as String,
      currentStatus: map['current_status'] as String,
      relationship: map['relationship'] as String?,
      instagramLink: map['instagram_link'] as String?,
      linkedinLink: map['linkedin_link'] as String?,
      facebookLink: map['facebook_link'] as String?,
      contactNumber: map['contact_number'] as String,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Create a copy with updated fields.
  Prospect copyWith({
    String? id,
    String? name,
    String? connectionType,
    String? place,
    String? currentStatus,
    String? relationship,
    String? instagramLink,
    String? linkedinLink,
    String? facebookLink,
    String? contactNumber,
    DateTime? createdAt,
  }) {
    return Prospect(
      id: id ?? this.id,
      name: name ?? this.name,
      connectionType: connectionType ?? this.connectionType,
      place: place ?? this.place,
      currentStatus: currentStatus ?? this.currentStatus,
      relationship: relationship ?? this.relationship,
      instagramLink: instagramLink ?? this.instagramLink,
      linkedinLink: linkedinLink ?? this.linkedinLink,
      facebookLink: facebookLink ?? this.facebookLink,
      contactNumber: contactNumber ?? this.contactNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
