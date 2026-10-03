import '../../models/audit_log.dart';
import '../../models/invitation.dart';
import '../../models/org_member.dart';
import '../../services/api_client.dart';
import '../org_repository.dart';

class RemoteOrgRepository implements OrgRepository {
  RemoteOrgRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<List<OrgMember>> listMembers() async {
    final json = await _api.get('/api/members') as List<dynamic>;
    return json.map((e) => OrgMember.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<void> setMemberRole(String memberId, MemberRole role) =>
      _api.patch('/api/members/$memberId/role', body: {'role': role.name});

  @override
  Future<void> setMemberActive(String memberId, {required bool active}) =>
      _api.post('/api/members/$memberId/${active ? 'reactivate' : 'deactivate'}');

  @override
  Future<void> transferOwnership(String memberId) => _api.post('/api/members/$memberId/transfer-ownership');

  @override
  Future<OrganizationInfo> getOrganization() async =>
      OrganizationInfo.fromJson(await _api.get('/api/organization') as Map<String, dynamic>);

  @override
  Future<OrganizationInfo> updateOrganization({required String name, required String address, required String phone}) async {
    final json = await _api.put('/api/organization', body: {'name': name, 'address': address, 'phone': phone});
    return OrganizationInfo.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<List<Invitation>> listInvitations() async {
    final json = await _api.get('/api/invitations') as List<dynamic>;
    return json.map((e) => Invitation.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<Invitation> createInvitation({required MemberRole role, required int expireDays, String note = ''}) async {
    final json = await _api.post('/api/invitations', body: {'role': role.name, 'expireDays': expireDays, 'note': note});
    return Invitation.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> extendInvitation(String id) => _api.post('/api/invitations/$id/extend');

  @override
  Future<void> cancelInvitation(String id) => _api.post('/api/invitations/$id/cancel');

  @override
  Future<AuditLogPage> listAuditLogs({AuditEntityType? type, String? before}) async {
    final json = await _api.get('/api/organization/audit-logs', query: {
      'type': ?type?.name,
      'before': ?before,
    }) as Map<String, dynamic>;
    return AuditLogPage(
      items: [for (final e in json['items'] as List<dynamic>) AuditLogEntry.fromJson(e as Map<String, dynamic>)],
      nextBefore: json['nextBefore'] as String?,
    );
  }
}
