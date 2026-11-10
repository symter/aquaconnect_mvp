/// A member's role within their org. 원장 (director) is the only role with
/// the institute's admin features (직원 관리, 초대, 관리원 정보 수정, 변경 이력,
/// editing/deleting others' memos) — the server enforces the same rule.
/// 원장 is granted and revoked only from the admin dashboard, never in-app.
enum MemberRole { director, staff, employee }

extension MemberRoleLabel on MemberRole {
  String get label => switch (this) {
        MemberRole.director => '원장',
        MemberRole.staff => '수산질병관리사',
        MemberRole.employee => '직원',
      };
}

/// 'owner' (소유자) was merged into 원장 — an older server may still send it.
MemberRole roleFromWire(String? wire) {
  if (wire == 'owner') return MemberRole.director;
  return MemberRole.values.firstWhere((r) => r.name == wire, orElse: () => MemberRole.staff);
}

/// Roles a 원장 can give in-app (role change and invites) — never 원장.
const inAppAssignableRoles = [MemberRole.staff, MemberRole.employee];

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

  /// 원장 — may use the institute's admin features.
  bool get isDirector => role == MemberRole.director;

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        id: json['id'] as String,
        orgId: json['orgId'] as String,
        name: json['name'] as String,
        role: roleFromWire(json['role'] as String?),
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
