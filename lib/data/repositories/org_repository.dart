import '../models/audit_log.dart';
import '../models/invitation.dart';
import '../models/org_member.dart';

/// The signed-in member's institute: its roster (구성원 관리), its info
/// (관리원 정보) and its 변경 이력.
abstract class OrgRepository {
  Future<List<OrgMember>> listMembers();

  Future<void> setMemberRole(String memberId, MemberRole role);

  Future<void> setMemberActive(String memberId, {required bool active});

  /// The signed-in owner hands ownership to [memberId] and becomes 원장.
  Future<void> transferOwnership(String memberId);

  Future<OrganizationInfo> getOrganization();

  Future<OrganizationInfo> updateOrganization({required String name, required String address, required String phone});

  /// Invites not yet used or cancelled (expired ones included).
  Future<List<Invitation>> listInvitations();

  Future<Invitation> createInvitation({required MemberRole role, required int expireDays, String note = ''});

  /// 기한 연장: the invite is valid for 7 more days from now.
  Future<void> extendInvitation(String id);

  Future<void> cancelInvitation(String id);

  /// [type] null = every kind; [before] = [AuditLogPage.nextBefore].
  Future<AuditLogPage> listAuditLogs({AuditEntityType? type, String? before});
}
