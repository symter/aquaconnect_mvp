import '../../models/app_notification.dart';
import '../../services/web_push_service.dart';
import '../notification_repository.dart';

/// In-memory inbox for mock mode. There's no server to send Web Push from,
/// so [pushPublicKey] is null and the UI reports push as unavailable.
class MockNotificationRepository implements NotificationRepository {
  final List<AppNotification> _items = [];
  NotificationSettings _settings = NotificationSettings.defaults;

  @override
  Future<NotificationFeed> fetchFeed() async =>
      NotificationFeed(items: List.of(_items), unreadCount: _items.where((n) => !n.isRead).length);

  @override
  Future<void> markRead(String id) async {
    final i = _items.indexWhere((n) => n.id == id);
    if (i != -1) _items[i] = _items[i].markedRead(DateTime.now());
  }

  @override
  Future<void> markAllRead() async {
    final now = DateTime.now();
    for (var i = 0; i < _items.length; i++) {
      _items[i] = _items[i].markedRead(now);
    }
  }

  @override
  Future<NotificationSettings> getSettings() async => _settings;

  @override
  Future<NotificationSettings> updateSettings(NotificationSettings settings) async => _settings = settings;

  @override
  Future<String?> pushPublicKey() async => null;

  @override
  Future<void> saveSubscription(PushSubscriptionInfo subscription) async {}

  @override
  Future<void> deleteSubscription(String endpoint) async {}

  @override
  Future<void> sendTest() async {
    final now = DateTime.now();
    _items.insert(
      0,
      AppNotification(
        id: 'n-${now.microsecondsSinceEpoch}',
        type: 'test',
        title: 'AquaConnect 테스트 알림',
        body: '알림이 정상적으로 도착했어요.',
        link: '/notifications',
        createdAt: now,
      ),
    );
  }
}
