/// One AI 관리 리포트 (ported from symterAI): an AI draft built from a farm's
/// memos over a chosen period, which staff can edit and then 확정.
///
/// [body] is "## 섹션" headings followed by "- 항목" lines; items carry
/// inline 〔근거: …〕 / 〔확인 필요: …〕 tags written by the server's
/// evidence check.
class AiReport {
  const AiReport({
    required this.id,
    required this.farmId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
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
    this.body,
    this.aiBody,
    this.checks = const [],
    this.memos = const [],
  });

  final String id;
  final String farmId;

  /// KST calendar dates, "YYYY-MM-DD".
  final String periodStart;
  final String periodEnd;

  /// 'draft' | 'confirmed'
  final String status;
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

  /// Only filled on the detail fetch — list rows leave these empty.
  final String? body;
  final String? aiBody;
  final List<AiReportCheck> checks;
  final List<AiReportMemo> memos;

  bool get isConfirmed => status == 'confirmed';

  factory AiReport.fromJson(Map<String, dynamic> json) => AiReport(
        id: json['id'] as String,
        farmId: json['farmId'] as String,
        periodStart: json['periodStart'] as String,
        periodEnd: json['periodEnd'] as String,
        status: json['status'] as String,
        model: json['model'] as String? ?? '',
        memoCount: json['memoCount'] as int? ?? 0,
        commentCount: json['commentCount'] as int? ?? 0,
        checkCount: json['checkCount'] as int? ?? 0,
        edited: json['edited'] as bool? ?? false,
        createdByName: json['createdByName'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        editedByName: json['editedByName'] as String?,
        editedAt: json['editedAt'] == null ? null : DateTime.parse(json['editedAt'] as String),
        confirmedByName: json['confirmedByName'] as String?,
        confirmedAt: json['confirmedAt'] == null ? null : DateTime.parse(json['confirmedAt'] as String),
        body: json['body'] as String?,
        aiBody: json['aiBody'] as String?,
        checks: ((json['checks'] as List<dynamic>?) ?? [])
            .map((e) => AiReportCheck.fromJson(e as Map<String, dynamic>))
            .toList(),
        memos: ((json['memos'] as List<dynamic>?) ?? [])
            .map((e) => AiReportMemo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

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

/// A memo as it read when the report was generated (the input snapshot).
class AiReportMemo {
  const AiReportMemo({required this.id, required this.date, required this.kind, required this.author, required this.body});

  final String id;
  final String date;
  final String kind;
  final String author;
  final String body;

  factory AiReportMemo.fromJson(Map<String, dynamic> json) => AiReportMemo(
        id: json['id'] as String,
        date: json['date'] as String? ?? '',
        kind: json['kind'] as String? ?? '',
        author: json['author'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );
}

class AiModelStatus {
  const AiModelStatus({required this.configured, required this.model, required this.note});

  final bool configured;
  final String model;
  final String note;

  factory AiModelStatus.fromJson(Map<String, dynamic> json) => AiModelStatus(
        configured: json['configured'] as bool? ?? false,
        model: json['model'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );
}
