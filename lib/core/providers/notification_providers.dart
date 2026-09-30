import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_notification.dart';
import '../../data/services/web_push_service.dart';
import 'repository_providers.dart';

/// The signed-in member's 알림함, re-fetched every 30s (and immediately
/// whenever it's invalidated, e.g. when a push arrives). Empty when signed
/// out so it never polls without a session.
final notificationFeedProvider = StreamProvider.autoDispose<NotificationFeed>((ref) async* {
  final session = ref.watch(authStateProvider).valueOrNull;
  if (session == null) {
    yield NotificationFeed.empty;
    return;
  }
  final repo = ref.watch(notificationRepositoryProvider);
  while (true) {
    try {
      yield await repo.fetchFeed();
    } catch (_) {
      // A failed poll keeps showing the last feed; the next tick retries.
    }
    await Future<void>.delayed(const Duration(seconds: 30));
  }
});

final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(notificationFeedProvider).valueOrNull?.unreadCount ?? 0;
});

/// 마이페이지 > 알림 설정 — which kinds of notifications to receive.
final notificationSettingsProvider =
    AsyncNotifierProvider.autoDispose<NotificationSettingsNotifier, NotificationSettings>(NotificationSettingsNotifier.new);

class NotificationSettingsNotifier extends AutoDisposeAsyncNotifier<NotificationSettings> {
  @override
  Future<NotificationSettings> build() => ref.watch(notificationRepositoryProvider).getSettings();

  /// Applies [next] right away, then rolls back if the server rejects it.
  Future<void> save(NotificationSettings next) async {
    final previous = state.valueOrNull;
    state = AsyncValue.data(next);
    try {
      state = AsyncValue.data(await ref.read(notificationRepositoryProvider).updateSettings(next));
    } catch (e) {
      if (previous != null) state = AsyncValue.data(previous);
      rethrow;
    }
  }
}

class PushStatus {
  const PushStatus({required this.permission, required this.subscribed, required this.serverAvailable});

  final PushPermission permission;

  /// This browser holds a push subscription.
  final bool subscribed;

  /// The server can send Web Push (false in mock mode).
  final bool serverAvailable;

  bool get enabled => permission == PushPermission.granted && subscribed && serverAvailable;
}

/// Push state of *this device* (permission + subscription).
final pushStatusProvider = FutureProvider.autoDispose<PushStatus>((ref) async {
  final push = ref.watch(webPushServiceProvider);
  final repo = ref.watch(notificationRepositoryProvider);
  String? publicKey;
  try {
    publicKey = await repo.pushPublicKey();
  } catch (_) {
    publicKey = null;
  }
  PushSubscriptionInfo? subscription;
  try {
    subscription = await push.currentSubscription();
  } catch (_) {
    subscription = null;
  }
  return PushStatus(permission: push.permission, subscribed: subscription != null, serverAvailable: publicKey != null);
});

final pushControllerProvider = Provider<PushController>((ref) => PushController(ref));

/// Turns push on/off for this device and keeps the server's copy of the
/// subscription in sync.
class PushController {
  PushController(this._ref);

  final Ref _ref;

  WebPushService get _push => _ref.read(webPushServiceProvider);

  /// Asks for permission if needed (call from a tap), subscribes this
  /// browser and registers it with the server. Returns the resulting
  /// permission; throws [PushException] with a user-facing message on
  /// failure.
  Future<PushPermission> enable() async {
    var permission = _push.permission;
    if (permission == PushPermission.notAsked) permission = await _push.requestPermission();
    if (permission != PushPermission.granted) {
      _ref.invalidate(pushStatusProvider);
      return permission;
    }
    await _subscribeAndSave();
    _ref.invalidate(pushStatusProvider);
    return permission;
  }

  Future<void> disable() async {
    final endpoint = await _push.unsubscribe();
    if (endpoint != null) {
      try {
        await _ref.read(notificationRepositoryProvider).deleteSubscription(endpoint);
      } catch (_) {
        // The server drops dead endpoints on its own the next time it sends.
      }
    }
    _ref.invalidate(pushStatusProvider);
  }

  /// Before signing out: stop the server pushing this member's
  /// notifications to this browser (the browser keeps its subscription, so
  /// the next member to sign in here is re-registered by [syncIfGranted]).
  Future<void> detachBeforeSignOut() async {
    try {
      final subscription = await _push.currentSubscription();
      if (subscription != null) {
        await _ref.read(notificationRepositoryProvider).deleteSubscription(subscription.endpoint);
      }
    } catch (_) {}
  }

  /// Re-registers an already-granted browser with the server — after
  /// sign-in, a server data reset, or a VAPID key change. Silent: never
  /// prompts and never throws.
  Future<void> syncIfGranted() async {
    if (_push.permission != PushPermission.granted) return;
    try {
      await _subscribeAndSave();
    } catch (_) {}
    _ref.invalidate(pushStatusProvider);
  }

  Future<void> _subscribeAndSave() async {
    final repo = _ref.read(notificationRepositoryProvider);
    final publicKey = await repo.pushPublicKey();
    if (publicKey == null) throw const PushException('이 환경(Mock 모드)에서는 휴대폰 알림을 보낼 수 없어요.');
    final subscription = await _push.subscribe(publicKey);
    await repo.saveSubscription(subscription);
  }
}
