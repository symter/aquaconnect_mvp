/// A 댓글 on a memo, written by an institute member.
class MemoComment {
  const MemoComment({
    required this.id,
    required this.memoId,
    required this.authorName,
    required this.content,
    required this.createdAt,
    this.authorMemberId,
  });

  final String id;
  final String memoId;

  /// Null once the author's account is gone.
  final String? authorMemberId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  factory MemoComment.fromJson(Map<String, dynamic> json) => MemoComment(
        id: json['id'] as String,
        memoId: json['memoId'] as String,
        authorMemberId: json['authorMemberId'] as String?,
        authorName: json['authorName'] as String? ?? '',
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
