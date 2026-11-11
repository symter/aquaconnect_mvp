/// What a 변경 이력 entry is about.
enum AuditEntityType {
  memo('메모'),
  farm('양식장'),
  member('구성원'),
  organization('관리원');

  const AuditEntityType(this.label);
  final String label;
}

/// One changed field: "주소: A → B".
class AuditChange {
  const AuditChange({required this.label, required this.from, required this.to});

  final String label;
  final String from;
  final String to;

  /// A memo entry's snapshot line ("내용: …") rather than a "A → B" change:
  /// only one side is filled — [to] for something added, [from] for
  /// something removed.
  bool get isSnapshot => from.isEmpty || to.isEmpty;

  factory AuditChange.fromJson(Map<String, dynamic> json) => AuditChange(
        label: json['label'] as String? ?? '',
        from: json['from'] as String? ?? '',
        to: json['to'] as String? ?? '',
      );
}

/// A 변경 이력 entry (`GET /api/organization/audit-logs`). Kept 3 months.
class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.entityType,
    this.entityId,
    required this.entityName,
    required this.action,
    required this.changes,
    required this.createdAt,
  });

  final String id;
  final String actorName;
  final AuditEntityType entityType;

  /// The memo / farm / member it's about; null for 메모 일괄 업로드.
  final String? entityId;

  /// The member / farm / 관리원 name; a memo entry carries its farm's name.
  final String entityName;

  /// create · update · delete · role_change · deactivate · reactivate ·
  /// owner_transfer · password_reset (관리자 대시보드). Memos also have
  /// import · done · reopen · comment · comment_delete.
  final String action;
  final List<AuditChange> changes;
  final DateTime createdAt;

  /// Something was removed for good — shown in red, and under 삭제 기록.
  bool get isDeletion => action == 'delete' || action == 'comment_delete';

  /// "양식장 등록", "역할 변경", … — the headline for this entry.
  String get actionLabel => switch ((entityType, action)) {
        (AuditEntityType.memo, 'create') => '메모 등록',
        (AuditEntityType.memo, 'import') => '메모 일괄 업로드',
        (AuditEntityType.memo, 'update') => '메모 수정',
        (AuditEntityType.memo, 'done') => '메모 완료',
        (AuditEntityType.memo, 'reopen') => '메모 완료 취소',
        (AuditEntityType.memo, 'delete') => '메모 삭제',
        (AuditEntityType.memo, 'comment') => '댓글 등록',
        (AuditEntityType.memo, 'comment_delete') => '댓글 삭제',
        (AuditEntityType.memo, _) => '메모 변경',
        (AuditEntityType.organization, 'create') => '관리원 가입',
        (AuditEntityType.organization, _) => '관리원 정보 수정',
        (AuditEntityType.farm, 'create') => '양식장 등록',
        (AuditEntityType.farm, 'delete') => '양식장 삭제',
        (AuditEntityType.farm, _) => '양식장 정보 수정',
        (_, 'role_change') => '역할 변경',
        (_, 'deactivate') => '구성원 비활성화',
        (_, 'reactivate') => '구성원 재활성화',
        (_, 'password_reset') => '비밀번호 재설정',
        (_, 'owner_transfer') => '소유자 양도',
        (_, 'invite') => '구성원 초대',
        (_, 'invite_cancel') => '초대 취소',
        (_, 'join') => '초대로 합류',
        _ => '구성원 정보 변경',
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String,
        actorName: json['actorName'] as String? ?? '',
        entityType: AuditEntityType.values.byName(json['entityType'] as String),
        entityId: json['entityId'] as String?,
        entityName: json['entityName'] as String? ?? '',
        action: json['action'] as String,
        changes: [for (final c in json['changes'] as List<dynamic>? ?? const []) AuditChange.fromJson(c as Map<String, dynamic>)],
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class AuditLogPage {
  const AuditLogPage({required this.items, this.nextBefore});

  final List<AuditLogEntry> items;

  /// Pass back as `before` to load older entries; null when there are none.
  final String? nextBefore;
}

/// 마이페이지 > 관리원 정보.
class OrganizationInfo {
  const OrganizationInfo({required this.id, required this.name, required this.address, required this.phone, required this.businessRegNo});

  final String id;
  final String name;
  final String address;
  final String phone;
  final String businessRegNo;

  factory OrganizationInfo.fromJson(Map<String, dynamic> json) => OrganizationInfo(
        id: json['id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        businessRegNo: json['businessRegNo'] as String? ?? '',
      );
}
