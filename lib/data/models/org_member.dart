// MemberRole/MemberRoleLabel live in member.dart (the real auth model) and
// are reused here so the mock roster and the signed-in session speak the
// same role vocabulary.
export 'member.dart' show MemberRole, MemberRoleLabel;

import 'member.dart';

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
    this.email,
    this.phone,
    this.inviteTarget,
    this.inviteExpiresAt,
  });

  /// A row of `GET /api/members` (active or inactive — invites aren't
  /// server-backed yet).
  factory OrgMember.fromJson(Map<String, dynamic> json) => OrgMember(
        id: json['id'] as String,
        name: json['name'] as String,
        role: MemberRole.values.firstWhere((r) => r.name == json['role'], orElse: () => MemberRole.staff),
        status: json['status'] == 'inactive' ? MemberStatus.inactive : MemberStatus.active,
        joinedAt: DateTime.parse(json['joinedAt'] as String).toLocal(),
        isMe: json['isMe'] as bool? ?? false,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
      );

  final String id;
  final String name;
  final MemberRole role;
  final MemberStatus status;

  /// For an active/inactive member, the date they joined. For a pending
  /// invite, the date the invite was (most recently) sent.
  final DateTime joinedAt;
  final bool isMe;
  final String? email;
  final String? phone;

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
      email: email,
      phone: phone,
      inviteTarget: inviteTarget ?? this.inviteTarget,
      inviteExpiresAt: inviteExpiresAt ?? this.inviteExpiresAt,
    );
  }
}

/// Initial roster for [MemberManagementScreen]: just the signed-in member.
/// There is no members API yet, so invites / role changes made on that
/// screen live only in its local state.
List<OrgMember> rosterFromSession(Member me) {
  return [
    OrgMember(
      id: me.id,
      name: me.name,
      role: me.role,
      status: MemberStatus.active,
      joinedAt: DateTime.now(),
      isMe: true,
    ),
  ];
}
