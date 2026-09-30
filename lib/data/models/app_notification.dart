/// An entry in the 알림함 (notification inbox).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.link,
    this.readAt,
  });

  final String id;

  /// 'risk' (farm risk went up), 'memo' (someone else left a memo) or 'test'.
  final String type;
  final String title;
  final String body;

  /// In-app route to open on tap, e.g. `/reports/<farmId>`.
  final String? link;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  AppNotification markedRead(DateTime at) =>
      AppNotification(id: id, type: type, title: title, body: body, createdAt: createdAt, link: link, readAt: readAt ?? at);

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        link: json['link'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        readAt: json['readAt'] == null ? null : DateTime.parse(json['readAt'] as String),
      );
}

class NotificationFeed {
  const NotificationFeed({required this.items, required this.unreadCount});

  static const empty = NotificationFeed(items: [], unreadCount: 0);

  final List<AppNotification> items;
  final int unreadCount;

  factory NotificationFeed.fromJson(Map<String, dynamic> json) => NotificationFeed(
        items: (json['items'] as List<dynamic>).map((e) => AppNotification.fromJson(e as Map<String, dynamic>)).toList(),
        unreadCount: (json['unreadCount'] as num).toInt(),
      );
}

/// 마이페이지 > 알림 설정 — which kinds of notifications this member gets.
class NotificationSettings {
  const NotificationSettings({required this.riskAlerts, required this.memoAlerts});

  static const defaults = NotificationSettings(riskAlerts: true, memoAlerts: true);

  /// A farm's risk level went up (양호 → 주의 / 위험).
  final bool riskAlerts;

  /// Another member left a memo.
  final bool memoAlerts;

  NotificationSettings copyWith({bool? riskAlerts, bool? memoAlerts}) => NotificationSettings(
        riskAlerts: riskAlerts ?? this.riskAlerts,
        memoAlerts: memoAlerts ?? this.memoAlerts,
      );

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => NotificationSettings(
        riskAlerts: json['riskAlerts'] as bool? ?? true,
        memoAlerts: json['memoAlerts'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'riskAlerts': riskAlerts, 'memoAlerts': memoAlerts};
}
