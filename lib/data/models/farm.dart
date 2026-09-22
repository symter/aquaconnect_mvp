import 'risk_level.dart';

class Farm {
  const Farm({
    required this.id,
    required this.orgId,
    required this.name,
    required this.region,
    required this.address,
    required this.nearestStationCode,
    required this.nearestStationName,
    required this.riskLevel,
    required this.headline,
    required this.waterTemp,
    required this.lastVisitDays,
    this.assignedMemberName,
    this.ownerContact,
  });

  final String id;
  final String orgId;
  final String name;
  final String region;
  final String address;
  final String nearestStationCode;
  final String nearestStationName;
  final RiskLevel riskLevel;

  /// Short status line shown on the farm card, e.g. "오늘 폐사 12마리".
  final String headline;
  final double waterTemp;
  final int lastVisitDays;
  final String? assignedMemberName;
  final String? ownerContact;

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        region: json['region'] as String,
        address: json['address'] as String,
        nearestStationCode: json['nearestStationCode'] as String,
        nearestStationName: json['nearestStationName'] as String,
        riskLevel: RiskLevel.fromKey(json['riskLevel'] as String),
        headline: json['headline'] as String,
        waterTemp: (json['waterTemp'] as num).toDouble(),
        lastVisitDays: json['lastVisitDays'] as int,
        assignedMemberName: json['assignedMemberName'] as String?,
        ownerContact: json['ownerContact'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orgId': orgId,
        'name': name,
        'region': region,
        'address': address,
        'nearestStationCode': nearestStationCode,
        'nearestStationName': nearestStationName,
        'riskLevel': riskLevel.key,
        'headline': headline,
        'waterTemp': waterTemp,
        'lastVisitDays': lastVisitDays,
        'assignedMemberName': assignedMemberName,
        'ownerContact': ownerContact,
      };

  Farm copyWith({
    String? name,
    String? region,
    String? address,
    String? nearestStationCode,
    String? nearestStationName,
    String? ownerContact,
  }) {
    return Farm(
      id: id,
      orgId: orgId,
      name: name ?? this.name,
      region: region ?? this.region,
      address: address ?? this.address,
      nearestStationCode: nearestStationCode ?? this.nearestStationCode,
      nearestStationName: nearestStationName ?? this.nearestStationName,
      riskLevel: riskLevel,
      headline: headline,
      waterTemp: waterTemp,
      lastVisitDays: lastVisitDays,
      assignedMemberName: assignedMemberName,
      ownerContact: ownerContact ?? this.ownerContact,
    );
  }
}
