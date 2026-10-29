/// One AI 리포트 (ported from symterAI): an AI draft built from memos over a
/// chosen period, which staff edit, 확정 (each 확정 saves a 판) and — for a
/// farm report — 발송 to the farm's share link.
///
/// [type] 'farm' is one farm's 관리 리포트; 'agency' is the 종합 리포트 over
/// every farm of the institute ([farmId] null, never sent).
///
/// [body] is "## 섹션" headings followed by "- 항목" lines; items carry
/// inline 〔근거: …〕 / 〔확인 필요: …〕 tags written by the server's
/// evidence check.
class AiReport {
  const AiReport({
    required this.id,
    this.type = 'farm',
    required this.farmId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.version = 0,
    required this.model,
    required this.memoCount,
    required this.commentCount,
    required this.checkCount,
    required this.edited,
    required this.createdByName,
    required this.createdAt,
    this.editedByName,
    this.editedAt,
    this.confirmedByName,
    this.confirmedAt,
    this.sentByName,
    this.sentAt,
    this.body,
    this.aiBody,
    this.checks = const [],
    this.memos = const [],
    this.comments = const [],
    this.evidence = const [],
    this.meta,
    this.examples = const [],
    this.staged,
    this.finalOpinion = '',
    this.editedSections = const [],
    this.farmName,
    this.orgName,
  });

  final String id;

  /// 'farm' | 'agency'
  final String type;
  final String? farmId;

  /// KST calendar dates, "YYYY-MM-DD".
  final String periodStart;
  final String periodEnd;

  /// 'draft' | 'confirmed' | 'sent'
  final String status;

  /// How many 판 have been approved so far (0 = never 확정).
  final int version;
  final String model;
  final int memoCount;
  final int commentCount;

  /// Items the server's evidence check flagged 확인 필요.
  final int checkCount;

  /// [body] differs from what the AI wrote.
  final bool edited;
  final String createdByName;
  final DateTime createdAt;
  final String? editedByName;
  final DateTime? editedAt;
  final String? confirmedByName;
  final DateTime? confirmedAt;
  final String? sentByName;

  /// Last 발송 (also set while a new 판 is being drafted after a send).
  final DateTime? sentAt;

  /// Only filled on the detail fetch — list rows leave these empty.
  final String? body;
  final String? aiBody;
  final List<AiReportCheck> checks;
  final List<AiReportMemo> memos;
  final List<AiReportComment> comments;

  /// 근거 확인: per section, each AI item's rendered line and its memos.
  final List<AiEvidenceSection> evidence;

  /// Numbers for the report form (tiles, timeline, charts), computed by the
  /// server from the memos — `formMeta` in server/src/lib/ai/farmReport.js
  /// (farm) or `meta` in agencyReport.js (agency). Null on reports made
  /// before the form existed.
  final Map<String, dynamic>? meta;

  /// Approved reports put in the prompt as style examples.
  final List<Map<String, dynamic>> examples;

  /// Present when the memos were long enough to be 중간 정리'd first.
  final Map<String, dynamic>? staged;

  /// 전문가 최종 의견.
  final String finalOpinion;

  /// Sections whose text differs from the AI draft.
  final List<String> editedSections;

  /// Only on a report the farm received (the public share-link view).
  final String? farmName;
  final String? orgName;

  bool get isAgency => type == 'agency';
  bool get isDraft => status == 'draft';
  bool get isSent => status == 'sent';

  /// 확정 or 발송 — approved, no longer editable.
  bool get isConfirmed => status == 'confirmed' || status == 'sent';

  AiReportMemo? memoNumbered(int n) => memos.where((m) => m.n == n).firstOrNull;

  factory AiReport.fromJson(Map<String, dynamic> json) => AiReport(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'farm',
        farmId: json['farmId'] as String?,
        periodStart: json['periodStart'] as String,
        periodEnd: json['periodEnd'] as String,
        status: json['status'] as String,
        version: json['version'] as int? ?? 0,
        model: json['model'] as String? ?? '',
        memoCount: json['memoCount'] as int? ?? 0,
        commentCount: json['commentCount'] as int? ?? 0,
        checkCount: json['checkCount'] as int? ?? 0,
        edited: json['edited'] as bool? ?? false,
        createdByName: json['createdByName'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedByName: json['editedByName'] as String?,
        editedAt: _date(json['editedAt']),
        confirmedByName: json['confirmedByName'] as String?,
        confirmedAt: _date(json['confirmedAt']),
        sentByName: json['sentByName'] as String?,
        sentAt: _date(json['sentAt']),
        body: json['body'] as String?,
        aiBody: json['aiBody'] as String?,
        checks: _list(json['checks'], AiReportCheck.fromJson),
        memos: _list(json['memos'], AiReportMemo.fromJson),
        comments: _list(json['comments'], AiReportComment.fromJson),
        evidence: _list(json['evidence'], AiEvidenceSection.fromJson),
        meta: json['meta'] as Map<String, dynamic>?,
        examples: ((json['examples'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>(),
        staged: json['staged'] as Map<String, dynamic>?,
        finalOpinion: json['finalOpinion'] as String? ?? '',
        editedSections: ((json['editedSections'] as List<dynamic>?) ?? []).cast<String>(),
        farmName: json['farmName'] as String?,
        orgName: json['orgName'] as String?,
      );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.parse(v as String);
List<T> _list<T>(Object? v, T Function(Map<String, dynamic>) f) =>
    ((v as List<dynamic>?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();

class AiReportCheck {
  const AiReportCheck({required this.section, required this.text, required this.problem});

  final String section;
  final String text;
  final String problem;

  factory AiReportCheck.fromJson(Map<String, dynamic> json) => AiReportCheck(
        section: json['section'] as String? ?? '',
        text: json['text'] as String? ?? '',
        problem: json['problem'] as String? ?? '',
      );
}

/// One AI item's line as it was rendered into the body, and its 근거.
class AiEvidenceItem {
  const AiEvidenceItem({required this.line, required this.evidence, required this.commentRefs});

  final String line;

  /// Memo numbers ([AiReportMemo.n]).
  final List<int> evidence;

  /// Comment keys ([AiReportComment.key]).
  final List<String> commentRefs;

  factory AiEvidenceItem.fromJson(Map<String, dynamic> json) => AiEvidenceItem(
        line: json['line'] as String? ?? '',
        evidence: ((json['evidence'] as List<dynamic>?) ?? []).map((e) => (e as num).toInt()).toList(),
        commentRefs: ((json['commentRefs'] as List<dynamic>?) ?? []).cast<String>(),
      );
}

class AiEvidenceSection {
  const AiEvidenceSection({required this.title, required this.items});

  final String title;
  final List<AiEvidenceItem> items;

  factory AiEvidenceSection.fromJson(Map<String, dynamic> json) => AiEvidenceSection(
        title: json['title'] as String? ?? '',
        items: _list(json['items'], AiEvidenceItem.fromJson),
      );
}

/// A comment on a selected memo, as it read when the report was generated.
class AiReportComment {
  const AiReportComment({required this.key, required this.memoN, required this.date, required this.author, required this.body, required this.late});

  /// "C{memo number}-{k}"
  final String key;
  final int memoN;
  final String date;
  final String author;
  final String body;

  /// Written after the report period ended.
  final bool late;

  factory AiReportComment.fromJson(Map<String, dynamic> json) => AiReportComment(
        key: json['key'] as String? ?? '',
        memoN: (json['memoN'] as num?)?.toInt() ?? 0,
        date: json['date'] as String? ?? '',
        author: json['author'] as String? ?? '',
        body: json['body'] as String? ?? '',
        late: json['late'] as bool? ?? false,
      );
}

/// A memo as it read when the report was generated (the input snapshot).
class AiReportMemo {
  const AiReportMemo({
    required this.id,
    this.n,
    required this.date,
    required this.kind,
    required this.author,
    required this.body,
    this.period = 'current',
    this.farmName,
  });

  final String id;

  /// The number the AI saw it as ([#n]).
  final int? n;
  final String date;
  final String kind;
  final String author;
  final String body;

  /// 'current' (in the report period) | 'previous' (the comparison period).
  final String period;

  /// 종합 리포트 only.
  final String? farmName;

  factory AiReportMemo.fromJson(Map<String, dynamic> json) => AiReportMemo(
        id: json['id'] as String,
        n: (json['n'] as num?)?.toInt(),
        date: json['date'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        author: json['author'] as String? ?? '',
        body: json['body'] as String? ?? '',
        period: json['period'] as String? ?? 'current',
        farmName: json['farmName'] as String?,
      );
}

/// One approved 판.
class AiReportVersion {
  const AiReportVersion({
    required this.version,
    required this.body,
    required this.finalOpinion,
    required this.approvedByName,
    required this.approvedAt,
    required this.editedSections,
    required this.sends,
  });

  final int version;
  final String body;
  final String finalOpinion;
  final String approvedByName;
  final DateTime approvedAt;
  final List<String> editedSections;

  /// When this 판 went to the farm (empty = never sent).
  final List<({DateTime sentAt, String sentByName})> sends;

  factory AiReportVersion.fromJson(Map<String, dynamic> json) => AiReportVersion(
        version: (json['version'] as num).toInt(),
        body: json['body'] as String? ?? '',
        finalOpinion: json['finalOpinion'] as String? ?? '',
        approvedByName: json['approvedByName'] as String? ?? '',
        approvedAt: DateTime.parse(json['approvedAt'] as String),
        editedSections: ((json['editedSections'] as List<dynamic>?) ?? []).cast<String>(),
        sends: [
          for (final s in ((json['sends'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>())
            (sentAt: DateTime.parse(s['sentAt'] as String), sentByName: s['sentByName'] as String? ?? ''),
        ],
      );
}

/// 분류 점검: memos the automatic classification wasn't sure about.
class AiMemoReview {
  const AiMemoReview({required this.total, required this.unclassified, required this.deathsWithoutCount, required this.items});

  final int total;
  final int unclassified;
  final int deathsWithoutCount;
  final List<({String id, String farmName, String date, String kind, String body, String topic, List<String> reasons})> items;

  factory AiMemoReview.fromJson(Map<String, dynamic> json) => AiMemoReview(
        total: json['total'] as int? ?? 0,
        unclassified: json['unclassified'] as int? ?? 0,
        deathsWithoutCount: json['deathsWithoutCount'] as int? ?? 0,
        items: [
          for (final u in ((json['uncertain'] as List<dynamic>?) ?? []).cast<Map<String, dynamic>>())
            (
              id: u['id'] as String,
              farmName: u['farmName'] as String? ?? '',
              date: u['date'] as String? ?? '',
              kind: u['kind'] as String? ?? '',
              body: u['body'] as String? ?? '',
              topic: u['topic'] as String? ?? '',
              reasons: ((u['reasons'] as List<dynamic>?) ?? []).cast<String>(),
            ),
        ],
      );
}

/// Server AI connection, plus every model staff can pick and how much of
/// its daily allowance is left.
class AiModelStatus {
  const AiModelStatus({
    required this.configured,
    required this.model,
    required this.note,
    this.models = const [],
    this.resetsAt,
  });

  final bool configured;

  /// The server's default model id.
  final String model;
  final String note;
  final List<AiModelOption> models;

  /// When Google's daily limits next reset (midnight US Pacific).
  final DateTime? resetsAt;

  factory AiModelStatus.fromJson(Map<String, dynamic> json) => AiModelStatus(
        configured: json['configured'] as bool? ?? false,
        model: json['model'] as String? ?? '',
        note: json['note'] as String? ?? '',
        models: ((json['models'] as List<dynamic>?) ?? [])
            .map((e) => AiModelOption.fromJson(e as Map<String, dynamic>))
            .toList(),
        resetsAt: json['resetsAt'] == null ? null : DateTime.parse(json['resetsAt'] as String),
      );
}

/// One selectable model. [usedToday] counts requests *this server* sent
/// since the last reset — Gemini doesn't report the real remaining quota, so
/// calls made with the same key elsewhere aren't included.
class AiModelOption {
  const AiModelOption({
    required this.id,
    required this.label,
    required this.description,
    required this.dailyLimit,
    required this.usedToday,
    required this.tokensToday,
    required this.limited,
    required this.remaining,
  });

  final String id;
  final String label;
  final String description;
  final int dailyLimit;
  final int usedToday;
  final int tokensToday;

  /// The model's last call came back 429 (rate/daily limit hit) and nothing
  /// has succeeded since.
  final bool limited;
  final int remaining;

  bool get exhausted => remaining <= 0;

  factory AiModelOption.fromJson(Map<String, dynamic> json) => AiModelOption(
        id: json['id'] as String,
        label: json['label'] as String? ?? json['id'] as String,
        description: json['description'] as String? ?? '',
        dailyLimit: json['dailyLimit'] as int? ?? 0,
        usedToday: json['usedToday'] as int? ?? 0,
        tokensToday: json['tokensToday'] as int? ?? 0,
        limited: json['limited'] as bool? ?? false,
        remaining: json['remaining'] as int? ?? 0,
      );
}
