import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Browser notification permission, plus [unsupported] for browsers without
/// the Push API (notably iOS Safari unless the app is added to the home
/// screen).
enum PushPermission { unsupported, notAsked, granted, denied }

/// A browser push subscription in the shape the server stores.
class PushSubscriptionInfo {
  const PushSubscriptionInfo({required this.endpoint, required this.p256dh, required this.auth});

  final String endpoint;
  final String p256dh;
  final String auth;

  Map<String, dynamic> toJson() => {'endpoint': endpoint, 'p256dh': p256dh, 'auth': auth};
}

class PushException implements Exception {
  const PushException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Web Push on this device: permission, the `push_sw.js` service worker, and
/// the PushManager subscription. The worker is registered under its own
/// `push/` scope so it doesn't replace Flutter's flutter_service_worker.js.
class WebPushService {
  static const _workerUrl = 'push_sw.js';
  static const _workerScope = 'push/';

  bool get isSupported =>
      globalContext.has('Notification') &&
      globalContext.has('PushManager') &&
      (web.window.navigator as JSObject).has('serviceWorker');

  /// True on iPhone/iPad, where push only works once the app is added to
  /// the home screen.
  bool get isIos => RegExp(r'iPhone|iPad|iPod').hasMatch(web.window.navigator.userAgent);

  PushPermission get permission {
    if (!isSupported) return PushPermission.unsupported;
    return switch (web.Notification.permission) {
      'granted' => PushPermission.granted,
      'denied' => PushPermission.denied,
      _ => PushPermission.notAsked,
    };
  }

  /// Shows the browser's permission prompt. Must run from a user tap.
  Future<PushPermission> requestPermission() async {
    if (!isSupported) return PushPermission.unsupported;
    await web.Notification.requestPermission().toDart;
    return permission;
  }

  Future<web.ServiceWorkerRegistration> _registration() async {
    final container = web.window.navigator.serviceWorker;
    final registration = await container.register(_workerUrl.toJS, web.RegistrationOptions(scope: _workerScope)).toDart;
    // `navigator.serviceWorker.ready` tracks the page's own (root) scope, not
    // this one, so wait for this registration's worker to activate directly.
    for (var i = 0; i < 100 && registration.active == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (registration.active == null) throw const PushException('알림 서비스를 시작하지 못했어요. 다시 시도해주세요.');
    return registration;
  }

  /// The subscription this browser already holds, if any.
  Future<PushSubscriptionInfo?> currentSubscription() async {
    if (permission != PushPermission.granted) return null;
    final registration = await _registration();
    final subscription = await registration.pushManager.getSubscription().toDart;
    return subscription == null ? null : _toInfo(subscription);
  }

  /// Subscribes this browser with the server's VAPID [publicKey]. A browser
  /// holding a subscription for a different key (e.g. the server's keys
  /// changed) is re-subscribed.
  Future<PushSubscriptionInfo> subscribe(String publicKey) async {
    if (permission != PushPermission.granted) throw const PushException('알림 권한이 허용되지 않았어요.');
    final registration = await _registration();
    final manager = registration.pushManager;
    final key = _base64UrlDecode(publicKey);

    final existing = await manager.getSubscription().toDart;
    if (existing != null) {
      final existingKey = existing.options.applicationServerKey;
      if (existingKey != null && _sameBytes(existingKey.toDart.asUint8List(), key)) return _toInfo(existing);
      await existing.unsubscribe().toDart;
    }

    final subscription = await manager
        .subscribe(web.PushSubscriptionOptionsInit(userVisibleOnly: true, applicationServerKey: key.toJS))
        .toDart;
    return _toInfo(subscription);
  }

  /// Drops this browser's subscription; returns its endpoint so the server
  /// copy can be deleted too.
  Future<String?> unsubscribe() async {
    if (!isSupported) return null;
    final registration = await web.window.navigator.serviceWorker.getRegistration(_workerScope).toDart;
    final subscription = await registration?.pushManager.getSubscription().toDart;
    if (subscription == null) return null;
    final endpoint = subscription.endpoint;
    await subscription.unsubscribe().toDart;
    return endpoint;
  }

  /// Messages from `push_sw.js`: `{type: 'aquaconnect-push'}` when a push
  /// arrives, `{type: 'aquaconnect-open', link}` when its notification is
  /// tapped while the app is already open.
  Stream<Map<String, String?>> workerMessages() {
    if (!isSupported) return const Stream.empty();
    final controller = StreamController<Map<String, String?>>.broadcast();
    web.window.navigator.serviceWorker.addEventListener(
      'message',
      ((web.MessageEvent event) {
        final data = event.data;
        if (data == null || !data.isA<JSObject>()) return;
        final object = data as JSObject;
        String? read(String key) => object.has(key) ? (object[key] as JSString?)?.toDart : null;
        controller.add({'type': read('type'), 'link': read('link')});
      }).toJS,
    );
    return controller.stream;
  }

  PushSubscriptionInfo _toInfo(web.PushSubscription subscription) {
    String key(String name) {
      final buffer = subscription.getKey(name);
      if (buffer == null) throw const PushException('푸시 구독 키를 읽지 못했어요.');
      return base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
    }

    return PushSubscriptionInfo(endpoint: subscription.endpoint, p256dh: key('p256dh'), auth: key('auth'));
  }

  static Uint8List _base64UrlDecode(String value) {
    final padded = value.padRight(value.length + (4 - value.length % 4) % 4, '=');
    return base64Url.decode(padded);
  }

  static bool _sameBytes(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
