import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../models/memo.dart';

/// Longest edge photos are shrunk to before upload — plenty for a memo
/// thumbnail/viewer, and keeps each upload to a few hundred KB.
const _maxEdge = 1600;
const _jpegQuality = 0.82;

/// Draws [source] (a playing <video> or a decoded image) onto a canvas no
/// larger than [_maxEdge] and encodes it as JPEG.
MemoPhotoUpload encodeJpeg(web.CanvasImageSource source, int width, int height) {
  final scale = math.min(1.0, _maxEdge / math.max(width, height));
  final w = (width * scale).round();
  final h = (height * scale).round();
  final canvas = web.HTMLCanvasElement()
    ..width = w
    ..height = h;
  (canvas.getContext('2d')! as web.CanvasRenderingContext2D).drawImage(source, 0, 0, w, h);
  final dataUrl = canvas.toDataURL('image/jpeg', _jpegQuality.toJS);
  return MemoPhotoUpload(
    bytes: base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1)),
    contentType: 'image/jpeg',
  );
}

/// Opens the browser's file chooser for one image, then downscales it.
/// Resolves to null if the user cancels.
Future<MemoPhotoUpload?> pickPhotoFromAlbum() {
  final completer = Completer<MemoPhotoUpload?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..style.display = 'none';
  web.document.body!.append(input);

  void finish(MemoPhotoUpload? result, [Object? error]) {
    input.remove();
    if (completer.isCompleted) return;
    error == null ? completer.complete(result) : completer.completeError(error);
  }

  Future<void> onChange() async {
    final file = input.files?.item(0);
    if (file == null) return finish(null);
    try {
      final bitmap = await web.window.createImageBitmap(file).toDart;
      finish(encodeJpeg(bitmap, bitmap.width, bitmap.height));
    } catch (e) {
      finish(null, Exception('사진을 불러오지 못했어요.'));
    }
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      onChange();
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
