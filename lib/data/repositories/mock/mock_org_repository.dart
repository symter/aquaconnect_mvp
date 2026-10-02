import '../../models/audit_log.dart';
import '../../models/invitation.dart';
import '../../models/org_member.dart';
import '../auth_repository.dart';
import '../org_repository.dart';

/// In-memory roster / 관리원 정보 / 변경 이력 for mock mode, starting from the
/// signed-in member alone.
class MockOrgRepository implements OrgRepository {
  MockOrgRepository({required AuthRepository authRepository}) : _auth = authRepository;

  final AuthRepository _auth;
  List<OrgMember>? _roster;
  OrganizationInfo? _org;
  final List<AuditLogEntry> _log = [];
  final List<Invitation> _invites = [];

  List<OrgMember> get _members {
    final session = _auth.currentSession;
    return _roster ??= session == null ? [] : rosterFromSession(session.member);
  }

  OrgMember get _me => _members.firstWhere((m) => m.isMe);

  void _record(AuditEntityType type, String name, String action, List<AuditChange> changes) {
    final now = DateTime.now();
    _log.insert(
      0,
      AuditLogEntry(
        id: 'log-${now.microsecondsSinceEpoch}',
        actorName: _me.name,
        entityType: type,
        entityName: name,
        action: action,
        changes: changes,
        createdAt: now,
      ),
    );
  }

  int _index(String id) {
    final i = _members.indexWhere((m) => m.id == id);
    if (i == -1) throw Exception('구성원을 찾을 수 없습니다.');
    return i;
  }

  @override
  Future<List<OrgMember>> listMembers() async => List.of(_members);

  @override
  Future<void> setMemberRole(String memberId, MemberRole role) async {
    final i = _index(memberId);
    final before = _members[i];
    _members[i] = before.copyWith(role: role);
    _record(AuditEntityType.member, before.name, 'role_change', [AuditChange(label: '역할', from: before.role.label, to: role.label)]);
  }

  @override
  Future<void> setMemberActive(String memberId, {required bool active}) async {
    final i = _index(memberId);
    final before = _members[i];
    _members[i] = before.copyWith(status: active ? MemberStatus.active : MemberStatus.inactive);
    _record(AuditEntityType.member, before.name, active ? 'reactivate' : 'deactivate',
        [AuditChange(label: '상태', from: active ? '비활성' : '활성', to: active ? '활성' : '비활성')]);
  }

  @override
  Future<void> transferOwnership(String memberId) async {
    final target = _index(memberId);
    final me = _members.indexWhere((m) => m.isMe);
    _members[me] = _members[me].copyWith(role: MemberRole.director);
    _members[target] = _members[target].copyWith(role: MemberRole.owner);
    _record(AuditEntityType.member, _members[target].name, 'owner_transfer', const []);
  }

  @override
  Future<OrganizationInfo> getOrganization() async {
    final org = _auth.currentSession?.organization;
    return _org ??= OrganizationInfo(id: org?.id ?? '', name: org?.name ?? '', address: '', phone: '', businessRegNo: '');
  }

  @override
  Future<OrganizationInfo> updateOrganization({required String name, required String address, required String phone}) async {
    final before = await getOrganization();
    _org = OrganizationInfo(id: before.id, name: name, address: address, phone: phone, businessRegNo: before.businessRegNo);
    final changes = [
      if (before.name != name) AuditChange(label: '관리원명', from: before.name, to: name),
      if (before.address != address) AuditChange(label: '주소', from: before.address, to: address),
      if (before.phone != phone) AuditChange(label: '대표 연락처', from: before.phone, to: phone),
    ];
    if (changes.isNotEmpty) _record(AuditEntityType.organization, name, 'update', changes);
    return _org!;
  }

  @override
  Future<List<Invitation>> listInvitations() async => List.of(_invites);

  @override
  Future<Invitation> createInvitation({required MemberRole role, required int expireDays, String note = ''}) async {
    final now = DateTime.now();
    final invite = Invitation(
      id: 'inv-${now.microsecondsSinceEpoch}',
      code: now.microsecondsSinceEpoch.toRadixString(36).toUpperCase(),
      role: role,
      note: note,
      createdAt: now,
      expiresAt: now.add(Duration(days: expireDays)),
      expired: false,
    );
    _invites.insert(0, invite);
    _record(AuditEntityType.member, note.isEmpty ? '초대 링크' : note, 'invite', [AuditChange(label: '초대 역할', from: '', to: role.label)]);
    return invite;
  }

  @override
  Future<void> extendInvitation(String id) async {
    final i = _invites.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = _invites[i];
    final now = DateTime.now();
    _invites[i] = Invitation(
      id: old.id,
      code: old.code,
      role: old.role,
      note: old.note,
      createdAt: now,
      expiresAt: now.add(old.expiresAt.difference(old.createdAt)),
      expired: false,
    );
  }

  @override
  Future<void> cancelInvitation(String id) async {
    final i = _invites.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final removed = _invites.removeAt(i);
    _record(AuditEntityType.member, removed.note.isEmpty ? '초대 링크' : removed.note, 'invite_cancel', const []);
  }

  @override
  Future<AuditLogPage> listAuditLogs({AuditEntityType? type, String? before}) async =>
      AuditLogPage(items: _log.where((e) => type == null || e.entityType == type).toList());
}
