/// A member's role within their org. MVP-stage: purely a display label and
/// a gate for a handful of UI affordances (e.g. who sees the weekly-digest
/// toggle) — there is no server-side permission enforcement per role yet.
enum MemberRole { owner, director, staff, employee }

extension MemberRoleLabel on MemberRole {
  String get label => switch (this) {
        MemberRole.owner => '소유자',
        MemberRole.director => '원장',
        MemberRole.staff => '수산질병관리사',
        MemberRole.employee => '직원',
      };
}

MemberRole _roleFromWire(String? wire) {
  return MemberRole.values.firstWhere((r) => r.name == wire, orElse: () => MemberRole.staff);
}

class Member {
  const Member({
    required this.id,
    required this.orgId,
    required this.name,
    required this.role,
    this.phone,
  });

  final String id;
  final String orgId;
  final String name;
  final MemberRole role;
  final String? phone;

  /// True only for the org's single owner. Kept as a convenience getter —
  /// most call sites care about "is this the owner", not the full role.
  bool get isOwner => role == MemberRole.owner;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        role: _roleFromWire(json['role'] as String?),
        phone: json['phone'] as String?,
      );
}

class Organization {
  const Organization({required this.id, required this.name});

  final String id;
  final String name;

  factory Organization.fromJson(Map<String, dynamic> json) => Organization(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}
