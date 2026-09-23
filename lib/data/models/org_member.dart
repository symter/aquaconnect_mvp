/// Role within an organization's roster. MVP-stage: purely a display label —
/// there is no permission branching by role. See [OrgMember].
enum MemberRole { owner, director, staff }

extension MemberRoleLabel on MemberRole {
  String get label => switch (this) {
        MemberRole.owner => '소유자',
        MemberRole.director => '원장',
        MemberRole.staff => '수산질병관리사',
      };
}

enum MemberStatus { active, pending, inactive }

/// A row in the "구성원 관리" (member management) roster. Distinct from
/// [Member] in `member.dart`, which models only the *currently signed-in*
/// user for auth — this models every member of the org, including invites
/// that haven't been accepted yet.
class OrgMember {
  const OrgMember({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    required this.joinedAt,
    this.isMe = false,
    this.inviteTarget,
    this.inviteExpiresAt,
  });

  final String id;
  final String name;
  final MemberRole role;
  final MemberStatus status;

  /// For an active/inactive member, the date they joined. For a pending
  /// invite, the date the invite was (most recently) sent.
  final DateTime joinedAt;
  final bool isMe;

  /// Pending invites only: "010-1234-5678" or "카카오톡 발송됨".
  final String? inviteTarget;
  final DateTime? inviteExpiresAt;

  OrgMember copyWith({
    String? name,
    MemberRole? role,
    MemberStatus? status,
    DateTime? joinedAt,
    bool? isMe,
    String? inviteTarget,
    DateTime? inviteExpiresAt,
  }) {
    return OrgMember(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      joinedAt: joinedAt ?? this.joinedAt,
      isMe: isMe ?? this.isMe,
      inviteTarget: inviteTarget ?? this.inviteTarget,
      inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
    );
  }
}

/// Mock roster seeding [MemberManagementScreen] — 6 members spanning every
/// role/status combination the screen needs to render.
List<OrgMember> mockOrgMembers() {
  final now = DateTime.now();
  return [
    OrgMember(
      id: 'om-1',
      name: '이동길',
      role: MemberRole.owner,
      status: MemberStatus.active,
      joinedAt: now.subtract(const Duration(days: 420)),
      isMe: true,
    ),
    OrgMember(
      id: 'om-2',
      name: '이원장',
      role: MemberRole.director,
      status: MemberStatus.active,
      joinedAt: now.subtract(const Duration(days: 300)),
    ),
    OrgMember(
      id: 'om-3',
      name: '박관리',
      role: MemberRole.staff,
      status: MemberStatus.active,
      joinedAt: now.subtract(const Duration(days: 200)),
    ),
    OrgMember(
      id: 'om-4',
      name: '최관리',
      role: MemberRole.staff,
      status: MemberStatus.active,
      joinedAt: now.subtract(const Duration(days: 90)),
    ),
    OrgMember(
      id: 'om-5',
      name: '010-9876-5432',
      role: MemberRole.staff,
      status: MemberStatus.pending,
      joinedAt: now.subtract(const Duration(days: 3)),
      inviteTarget: '010-9876-5432',
      inviteExpiresAt: now.add(const Duration(days: 4)),
    ),
    OrgMember(
      id: 'om-6',
      name: '정퇴사',
      role: MemberRole.staff,
      status: MemberStatus.inactive,
      joinedAt: now.subtract(const Duration(days: 500)),
    ),
  ];
}
