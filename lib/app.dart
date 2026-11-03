import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers/notification_providers.dart';
import 'core/providers/repository_providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/responsive_mobile_frame.dart';

class AquaConnectApp extends ConsumerStatefulWidget {
  const AquaConnectApp({super.key});

  @override
  ConsumerState<AquaConnectApp> createState() => _AquaConnectAppState();
}

class _AquaConnectAppState extends ConsumerState<AquaConnectApp> {
  StreamSubscription<Map<String, String?>>? _pushMessages;

  @override
  void initState() {
    super.initState();
    // Messages from push_sw.js: refresh the 알림함 when a push lands, and
    // open the right screen when its notification is tapped while the app
    // is already open.
    _pushMessages = ref.read(webPushServiceProvider).workerMessages().listen((message) {
      ref.invalidate(notificationFeedProvider);
      final link = message['link'];
      if (message['type'] == 'aquaconnect-open' && link != null) openAppLink(ref.read(routerProvider), link);
    });
  }

  @override
  void dispose() {
    _pushMessages?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // After every sign-in (including a restored session), make sure this
    // browser — if it already allowed notifications — is registered to the
    // member now signed in.
    ref.listen(authStateProvider, (previous, next) {
      if (previous?.valueOrNull == null && next.valueOrNull != null) {
        ref.read(pushControllerProvider).syncIfGranted();
      }
    });

    return MaterialApp.router(
      title: 'AquaConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // One layout rule for every screen (and the sheets/dialogs on top):
      // full width on phones and portrait tablets, a centered column on
      // wider windows — wider for the calendar. Very large system font sizes
      // are capped so small phones don't break.
      builder: (context, child) => _AppFrame(router: router, child: child ?? const SizedBox.shrink()),
    );
  }
}

/// Full width on phones and portrait tablets, a centered column on wider
/// windows (wider on the calendar), and very large system font sizes capped
/// so small phones don't break.
///
/// The router can notify while a frame is being built (first load,
/// redirects), so the width switch is applied after the frame, and only when
/// it actually changes.
class _AppFrame extends StatefulWidget {
  const _AppFrame({required this.router, required this.child});

  final GoRouter router;
  final Widget child;

  @override
  State<_AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<_AppFrame> {
  late bool _wide = _isWide();

  bool _isWide() {
    try {
      return widget.router.routerDelegate.currentConfiguration.uri.path.startsWith('/calendar');
    } catch (_) {
      return false;
    }
  }

  void _onRoute() {
    final wide = _isWide();
    if (wide == _wide) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isWide() != _wide) setState(() => _wide = _isWide());
    });
  }

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_onRoute);
  }

  @override
  void didUpdateWidget(_AppFrame old) {
    super.didUpdateWidget(old);
    if (old.router != widget.router) {
      old.router.routerDelegate.removeListener(_onRoute);
      widget.router.routerDelegate.addListener(_onRoute);
      _wide = _isWide();
    }
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3)),
      child: ResponsiveMobileFrame(
        maxWidth: _wide ? ResponsiveMobileFrame.wideWidth : ResponsiveMobileFrame.contentWidth,
        child: widget.child,
      ),
    );
  }
}
