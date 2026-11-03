/// What the server read from a memo file (메모 일괄 업로드): an Excel CSV or a
/// 메모장 text. [created] is 0 for a dry run.
class MemoImportResult {
  const MemoImportResult({required this.format, required this.memos, required this.warnings, required this.created});

  /// 'csv' | 'text'
  final String format;
  final List<ImportedMemo> memos;

  /// Lines that were skipped, and why.
  final List<String> warnings;
  final int created;

  int get freshCount => memos.where((m) => !m.duplicate).length;

  factory MemoImportResult.fromJson(Map<String, dynamic> json) => MemoImportResult(
        format: json['format'] as String? ?? '',
        memos: ((json['memos'] as List<dynamic>?) ?? []).map((e) => ImportedMemo.fromJson(e as Map<String, dynamic>)).toList(),
        warnings: ((json['warnings'] as List<dynamic>?) ?? []).cast<String>(),
        created: json['created'] as int? ?? 0,
      );
}

class ImportedMemo {
  const ImportedMemo({required this.date, required this.kind, required this.body, required this.duplicate});

  /// KST "YYYY-MM-DD" the memo is filed under.
  final String date;

  /// The 종류 tag (폐사·접종·방문·배달·할일), or null when none could be read.
  final String? kind;
  final String body;

  /// Already in the app (same farm, day and text) — skipped on upload.
  final bool duplicate;

  factory ImportedMemo.fromJson(Map<String, dynamic> json) => ImportedMemo(
        date: json['date'] as String? ?? '',
        kind: json['kind'] as String?,
        body: json['body'] as String? ?? '',
        duplicate: json['duplicate'] as bool? ?? false,
      );
}
