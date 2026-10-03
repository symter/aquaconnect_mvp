import 'member.dart';

/// A 구성원 초대 link (`/#/invite/<code>`), single-use.
class Invitation {
  const Invitation({
    required this.id,
    required this.code,
    required this.role,
    required this.note,
    required this.createdAt,
    required this.expiresAt,
    required this.expired,
  });

  final String id;
  final String code;
  final MemberRole role;

  /// Who it was meant for, as the inviter typed it. May be empty.
  final String note;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool expired;

  /// The link to send — the app uses hash routing.
  String get url => '${Uri.base.origin}/#/invite/$code';

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation(
        id: json['id'] as String,
        code: json['code'] as String,
        role: MemberRole.values.firstWhere((r) => r.name == json['role'], orElse: () => MemberRole.staff),
        note: json['note'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        expired: json['status'] == 'expired',
      );
}

/// What the invite page shows before signing up (`GET /api/public/invitations/:code`).
class InvitationInfo {
  const InvitationInfo({
    required this.orgName,
    required this.role,
    required this.inviterName,
    required this.expiresAt,
    required this.termsVersion,
  });

  final String orgName;
  final MemberRole role;
  final String inviterName;
  final DateTime expiresAt;
  final String termsVersion;

  factory InvitationInfo.fromJson(Map<String, dynamic> json) => InvitationInfo(
        orgName: json['orgName'] as String,
        role: MemberRole.values.firstWhere((r) => r.name == json['role'], orElse: () => MemberRole.staff),
        inviterName: json['inviterName'] as String? ?? '',
        expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
        termsVersion: json['termsVersion'] as String? ?? '',
      );
}

/// The invitee's details when accepting an invite.
class InviteAcceptRequest {
  const InviteAcceptRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.termsVersion,
    required this.marketingAgreed,
  });

  final String name;
  final String email;
  final String password;
  final String phone;
  final String termsVersion;
  final bool marketingAgreed;

  Map<String, dynamic> toJson() => {
        'account': {'name': name, 'email': email, 'password': password, 'phone': phone},
        // Submitting requires both required terms to be checked.
        'terms': {'termsVersion': termsVersion, 'termsAgreed': true, 'privacyAgreed': true, 'marketingAgreed': marketingAgreed},
      };
}
