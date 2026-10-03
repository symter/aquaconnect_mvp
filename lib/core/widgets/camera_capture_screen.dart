import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../../data/models/memo.dart';
import '../../data/services/photo_capture.dart';

/// Full-screen in-app camera. Asks the browser for camera permission, shows
/// a live preview (rear camera preferred) and returns the captured photo,
/// already downscaled. Falls back to the album picker when the camera
/// can't be used.
class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  static Future<MemoPhotoUpload?> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<MemoPhotoUpload>(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => const CameraCaptureScreen()),
    );
  }

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen> {
  final _viewType = 'memo-camera-${DateTime.now().microsecondsSinceEpoch}';
  final _video = web.HTMLVideoElement();
  web.MediaStream? _stream;
  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _video
      ..autoplay = true
      ..muted = true
      ..setAttribute('playsinline', '')
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _video);
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _ready = false;
    });
    if (!web.window.isSecureContext) {
      setState(() => _error = '카메라는 보안 연결(https)에서만 사용할 수 있어요.');
      return;
    }
    try {
      final constraints = web.MediaStreamConstraints(
        video: {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1920},
          'height': {'ideal': 1080},
        }.jsify()!,
        audio: false.toJS,
      );
      final stream = await web.window.navigator.mediaDevices.getUserMedia(constraints).toDart;
      if (!mounted) {
        _stopTracks(stream);
        return;
      }
      _stream = stream;
      _video.srcObject = stream;
      await _video.play().toDart;
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _error = _describe(_errorName(e)));
    }
  }

  /// getUserMedia rejects with a DOMException whose `name` (e.g.
  /// NotAllowedError) identifies the cause; toString() on the caught JS
  /// object doesn't reliably include it.
  String _errorName(Object e) {
    try {
      final name = (e as JSObject).getProperty<JSString?>('name'.toJS)?.toDart;
      if (name != null) return name;
    } catch (_) {}
    return e.toString();
  }

  String _describe(String error) {
    if (error.contains('NotAllowed') || error.contains('PermissionDenied')) {
      return '카메라 권한이 거부되었어요.\n브라우저 주소창의 사이트 설정(자물쇠 아이콘)에서 카메라를 허용한 뒤 다시 시도해주세요.';
    }
    if (error.contains('NotFound') || error.contains('Overconstrained')) {
      return '사용할 수 있는 카메라를 찾지 못했어요.';
    }
    if (error.contains('NotReadable')) {
      return '다른 앱이 카메라를 사용 중이에요. 다른 앱을 닫고 다시 시도해주세요.';
    }
    if (error.contains('NotSupported')) {
      return '이 브라우저에서는 카메라를 사용할 수 없어요.';
    }
    return '카메라를 시작하지 못했어요.';
  }

  void _stopTracks(web.MediaStream stream) {
    for (final track in stream.getTracks().toDart) {
      track.stop();
    }
  }

  void _capture() {
    final w = _video.videoWidth;
    final h = _video.videoHeight;
    if (!_ready || w == 0 || h == 0) return;
    Navigator.of(context).pop(encodeJpeg(_video, w, h));
  }

  Future<void> _pickFromAlbum() async {
    try {
      final photo = await pickPhotoFromAlbum();
      if (photo != null && mounted) Navigator.of(context).pop(photo);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    final stream = _stream;
    if (stream != null) _stopTracks(stream);
    _video.srcObject = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: '닫기',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Expanded(
              child: _error != null
                  ? _ErrorView(message: _error!, onRetry: _start)
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        HtmlElementView(viewType: _viewType),
                        if (!_ready)
                          const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 12),
                                Text('카메라를 준비하는 중… (권한을 요청하면 허용해주세요)',
                                    style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _RoundTextButton(icon: Icons.photo_library_outlined, label: '앨범', onTap: _pickFromAlbum),
                  GestureDetector(
                    onTap: _ready ? _capture : null,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                      ),
                      padding: const EdgeInsets.all(5),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ready ? Colors.white : Colors.white24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 56),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, size: 40, color: Colors.white54),
            const SizedBox(height: 14),
            Text(message,
                textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.5)),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
              child: const Text('다시 시도'),
            ),
            const SizedBox(height: 6),
            const Text('또는 아래 "앨범"에서 사진을 선택할 수 있어요.',
                style: TextStyle(color: Colors.white54, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class _RoundTextButton extends StatelessWidget {
  const _RoundTextButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
