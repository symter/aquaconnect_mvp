import '../models/app_notification.dart';
import '../services/web_push_service.dart';

abstract class NotificationRepository {
  Future<NotificationFeed> fetchFeed();

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<NotificationSettings> getSettings();

  Future<NotificationSettings> updateSettings(NotificationSettings settings);

  /// The server's VAPID public key, or null when push isn't available
  /// (mock mode).
  Future<String?> pushPublicKey();

  Future<void> saveSubscription(PushSubscriptionInfo subscription);

  Future<void> deleteSubscription(String endpoint);

  /// Sends a test notification to the signed-in member (inbox + push).
  Future<void> sendTest();
}
