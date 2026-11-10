import '../models/audit_log.dart';
import '../models/invitation.dart';
import '../models/org_member.dart';

/// The signed-in member's institute: its roster (직원 관리), its info
/// (관리원 정보) and its 변경 이력. Changes are 원장-only (server-enforced).
abstract class OrgRepository {
  Future<List<OrgMember>> listMembers();

  Future<void> setMemberRole(String memberId, MemberRole role);

  Future<void> setMemberActive(String memberId, {required bool active});

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
