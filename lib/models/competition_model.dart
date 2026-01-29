import 'package:cloud_firestore/cloud_firestore.dart';

class CompetitionModel {
  final String id;
  final String organizerId;
  final String organizerName;
  final String? sponsorName;
  final String name;
  final String sport;
  final String format;
  final bool isPublic;
  final String joinCode; // Unique 6-digit code
  final String fixtureType; // 'running' or 'full'
  final String? logoUrl;
  final String? cardBackgroundImageUrl;
  final String? description;
  final GeoPoint? organizerLocation;
  final String
  locationRestrictionType; // 'none', '20km', '50km', '100km', 'state', 'country'
  final double? restrictionRadius; // in kilometers
  final String? restrictionState;
  final String? restrictionCountry;
  final Map<String, int> rules; // {'correctWinner': 3, 'correctScore': 2}
  final bool isPaid;
  final List<String>? customImages; // For paid organizers
  final String? customCaption;
  final int participantCount;
  final DateTime createdAt;
  final DateTime? startDate;
  final DateTime? endDate;
  final int pointsForWin;
  final int pointsForDraw;
  final int pointsForLoss;
  final List<String>
  tieBreakerRules; // ['goal_difference', 'head_to_head', 'goals_scored'] (Ordered)
  final String? leagueId; // For Official Tournaments
  final DateTime? deletedAt; // For Recycle Bin (Soft Delete)
  final String? termsAndConditions; // New field for T&C
  final List<Map<String, dynamic>>? termsMetadata; // For T&C Editor State
  final String? termsLanguage; // Default language for T&C display
  final int numberOfGroups;
  final List<String> groups; // ['Group A', 'Group B']
  final String status; // 'draft', 'active', 'archived'

  CompetitionModel({
    required this.id,
    required this.organizerId,
    required this.organizerName,
    this.sponsorName,
    required this.name,
    required this.sport,
    required this.format,
    required this.isPublic,
    required this.joinCode,
    this.fixtureType = 'running',
    this.logoUrl,
    this.cardBackgroundImageUrl,
    this.description,
    this.organizerLocation,
    required this.locationRestrictionType,
    this.restrictionRadius,
    this.restrictionState,
    this.restrictionCountry,
    required this.rules,
    required this.isPaid,
    this.customImages,
    this.customCaption,
    required this.participantCount,
    required this.createdAt,
    this.startDate,
    this.endDate,
    this.pointsForWin = 3,
    this.pointsForDraw = 1,
    this.pointsForLoss = 0,
    this.tieBreakerRules = const ['goal_difference'],
    this.leagueId,
    this.deletedAt,
    this.termsAndConditions,
    this.termsMetadata,
    this.termsLanguage,
    this.numberOfGroups = 0,
    this.groups = const [],
    this.status = 'draft',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizerId': organizerId,
      'organizerName': organizerName,
      'sponsorName': sponsorName,
      'name': name,
      'sport': sport,
      'format': format,
      'isPublic': isPublic,
      'joinCode': joinCode,
      'fixtureType': fixtureType,
      'logoUrl': logoUrl,
      'cardBackgroundImageUrl': cardBackgroundImageUrl,
      'description': description,
      'organizerLocation': organizerLocation,
      'locationRestrictionType': locationRestrictionType,
      'status': status,
      'restrictionRadius': restrictionRadius,
      'restrictionState': restrictionState,
      'restrictionCountry': restrictionCountry,
      'rules': rules,
      'isPaid': isPaid,
      'customImages': customImages,
      'customCaption': customCaption,
      'participantCount': participantCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'pointsForWin': pointsForWin,
      'pointsForDraw': pointsForDraw,
      'pointsForLoss': pointsForLoss,
      'tieBreakerRules': tieBreakerRules,
      'leagueId': leagueId,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
      'termsAndConditions': termsAndConditions,
      'termsMetadata': termsMetadata,
      'termsLanguage': termsLanguage,
      'numberOfGroups': numberOfGroups,
      'groups': groups,
    };
  }

  factory CompetitionModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    // Handle legacy single tie-breaker rule
    List<String> parsedRules = [];
    if (map['tieBreakerRules'] != null) {
      parsedRules = List<String>.from(map['tieBreakerRules']);
    } else if (map['tieBreakerRule'] != null) {
      parsedRules = [map['tieBreakerRule']];
    } else {
      parsedRules = ['goal_difference'];
    }

    return CompetitionModel(
      id: documentId,
      organizerId: map['organizerId'] ?? '',
      organizerName: map['organizerName'] ?? '',
      sponsorName: map['sponsorName'],
      name: map['name'] ?? '',
      sport: map['sport'] ?? 'Football',
      format: map['format'] ?? 'League',
      isPublic: map['isPublic'] ?? true,
      joinCode: map['joinCode'] ?? '',
      fixtureType: map['fixtureType'] ?? 'running',
      logoUrl: map['logoUrl'],
      cardBackgroundImageUrl: map['cardBackgroundImageUrl'],
      description: map['description'],
      organizerLocation: map['organizerLocation'],
      locationRestrictionType: map['locationRestrictionType'] ?? 'none',
      restrictionRadius: map['restrictionRadius']?.toDouble(),
      restrictionState: map['restrictionState'],
      restrictionCountry: map['restrictionCountry'],
      rules: Map<String, int>.from(
        map['rules'] ?? {'correctWinner': 3, 'correctScore': 2},
      ),
      isPaid: map['isPaid'] ?? false,
      customImages: map['customImages'] != null
          ? List<String>.from(map['customImages'])
          : null,
      customCaption: map['customCaption'],
      participantCount: map['participantCount'] ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      startDate: map['startDate'] != null
          ? (map['startDate'] as Timestamp).toDate()
          : null,
      endDate: map['endDate'] != null
          ? (map['endDate'] as Timestamp).toDate()
          : null,
      pointsForWin: map['pointsForWin'] ?? 3,
      pointsForDraw: map['pointsForDraw'] ?? 1,
      pointsForLoss: map['pointsForLoss'] ?? 0,
      tieBreakerRules: parsedRules,
      leagueId: map['leagueId'],
      deletedAt: map['deletedAt'] != null
          ? (map['deletedAt'] as Timestamp).toDate()
          : null,
      termsAndConditions: map['termsAndConditions'],
      termsMetadata: map['termsMetadata'] != null
          ? List<Map<String, dynamic>>.from(map['termsMetadata'])
          : null,
      termsLanguage: map['termsLanguage'],
      numberOfGroups: map['numberOfGroups'] ?? 0,
      groups: map['groups'] != null
          ? List<String>.from(map['groups'])
          : const [],
      status: map['status'] ?? 'active',
    );
  }

  factory CompetitionModel.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return CompetitionModel.fromMap(data, snapshot.id);
  }

  CompetitionModel copyWith({
    String? id,
    String? organizerId,
    String? organizerName,
    String? sponsorName,
    String? name,
    String? sport,
    String? format,
    bool? isPublic,
    String? joinCode,
    String? fixtureType,
    String? logoUrl,
    String? cardBackgroundImageUrl,
    String? description,
    GeoPoint? organizerLocation,
    String? locationRestrictionType,
    double? restrictionRadius,
    String? restrictionState,
    String? restrictionCountry,
    Map<String, int>? rules,
    bool? isPaid,
    List<String>? customImages,
    String? customCaption,
    int? participantCount,
    DateTime? createdAt,
    DateTime? startDate,
    DateTime? endDate,
    int? pointsForWin,
    int? pointsForDraw,
    int? pointsForLoss,
    List<String>? tieBreakerRules,
    String? leagueId,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    String? termsAndConditions,
    List<Map<String, dynamic>>? termsMetadata,
    String? termsLanguage,
    int? numberOfGroups,
    List<String>? groups,
    String? status,
  }) {
    return CompetitionModel(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      organizerName: organizerName ?? this.organizerName,
      sponsorName: sponsorName ?? this.sponsorName,
      name: name ?? this.name,
      sport: sport ?? this.sport,
      format: format ?? this.format,
      isPublic: isPublic ?? this.isPublic,
      joinCode: joinCode ?? this.joinCode,
      fixtureType: fixtureType ?? this.fixtureType,
      logoUrl: logoUrl ?? this.logoUrl,
      cardBackgroundImageUrl:
          cardBackgroundImageUrl ?? this.cardBackgroundImageUrl,
      description: description ?? this.description,
      organizerLocation: organizerLocation ?? this.organizerLocation,
      locationRestrictionType:
          locationRestrictionType ?? this.locationRestrictionType,
      restrictionRadius: restrictionRadius ?? this.restrictionRadius,
      restrictionState: restrictionState ?? this.restrictionState,
      restrictionCountry: restrictionCountry ?? this.restrictionCountry,
      rules: rules ?? this.rules,
      isPaid: isPaid ?? this.isPaid,
      customImages: customImages ?? this.customImages,
      customCaption: customCaption ?? this.customCaption,
      participantCount: participantCount ?? this.participantCount,
      createdAt: createdAt ?? this.createdAt,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      pointsForWin: pointsForWin ?? this.pointsForWin,
      pointsForDraw: pointsForDraw ?? this.pointsForDraw,
      pointsForLoss: pointsForLoss ?? this.pointsForLoss,
      tieBreakerRules: tieBreakerRules ?? this.tieBreakerRules,
      leagueId: leagueId ?? this.leagueId,
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      termsMetadata: termsMetadata ?? this.termsMetadata,
      termsLanguage: termsLanguage ?? this.termsLanguage,
      numberOfGroups: numberOfGroups ?? this.numberOfGroups,
      groups: groups ?? this.groups,
      status: status ?? this.status,
    );
  }

  // Deprecated: Location restrictions are removed
  bool get hasLocationRestriction => false;
}
