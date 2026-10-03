import '../../models/app_notification.dart';
import '../../services/api_client.dart';
import '../../services/web_push_service.dart';
import '../notification_repository.dart';

class RemoteNotificationRepository implements NotificationRepository {
  RemoteNotificationRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  @override
  Future<NotificationFeed> fetchFeed() async {
    final json = await _api.get('/api/notifications') as Map<String, dynamic>;
    return NotificationFeed.fromJson(json);
  }

  @override
  Future<void> markRead(String id) => _api.post('/api/notifications/$id/read');

  @override
  Future<void> markAllRead() => _api.post('/api/notifications/read-all');

  @override
  Future<NotificationSettings> getSettings() async {
    final json = await _api.get('/api/notifications/settings') as Map<String, dynamic>;
    return NotificationSettings.fromJson(json);
  }

  @override
  Future<NotificationSettings> updateSettings(NotificationSettings settings) async {
    final json = await _api.put('/api/notifications/settings', body: settings.toJson()) as Map<String, dynamic>;
    return NotificationSettings.fromJson(json);
  }

  @override
  Future<String?> pushPublicKey() async {
    final json = await _api.get('/api/notifications/push/public-key') as Map<String, dynamic>;
    return json['publicKey'] as String?;
  }

  @override
  Future<void> saveSubscription(PushSubscriptionInfo subscription) =>
      _api.post('/api/notifications/push/subscriptions', body: subscription.toJson());

  @override
  Future<void> deleteSubscription(String endpoint) =>
      _api.delete('/api/notifications/push/subscriptions', body: {'endpoint': endpoint});

  @override
  Future<void> sendTest() => _api.post('/api/notifications/test');
}
