enum ShareLinkExpiry {
  sevenDays,
  thirtyDays,
  unlimited;

  String get label => switch (this) {
        ShareLinkExpiry.sevenDays => '7일',
        ShareLinkExpiry.thirtyDays => '30일',
        ShareLinkExpiry.unlimited => '무제한',
      };

  DateTime? expiresAtFrom(DateTime now) => switch (this) {
        ShareLinkExpiry.sevenDays => now.add(const Duration(days: 7)),
        ShareLinkExpiry.thirtyDays => now.add(const Duration(days: 30)),
        ShareLinkExpiry.unlimited => null,
      };
}

class ShareLink {
  const ShareLink({
    required this.id,
    required this.farmId,
    required this.token,
    required this.createdAt,
    this.expiresAt,
    this.revokedAt,
    this.farmName,
  });

  final String id;
  final String farmId;
  final String token;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;

  /// Present in the institute's link list (`GET /api/share-links`).
  final String? farmName;

  bool get isActive {
    if (revokedAt != null) return false;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }

  String urlPath() => '/r/$token';

  factory ShareLink.fromJson(Map<String, dynamic> json) => ShareLink(
        id: json['id'] as String,
        farmId: json['farmId'] as String,
        token: json['token'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: json['expiresAt'] == null ? null : DateTime.parse(json['expiresAt'] as String),
        revokedAt: json['revokedAt'] == null ? null : DateTime.parse(json['revokedAt'] as String),
        farmName: json['farmName'] as String?,
      );
}
