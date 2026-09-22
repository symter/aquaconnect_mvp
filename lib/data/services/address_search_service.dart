import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Result of a Daum(카카오) 우편번호 주소 검색, launched via [AddressSearchService].
class AddressSearchResult {
  const AddressSearchResult({required this.address, this.zonecode});

  final String address;
  final String? zonecode;
}

/// Opens the free Daum Postcode ("주소찾기") widget in a popup window
/// (`web/postcode.html`) and resolves with the road-name address the user
/// picked, via a `window.postMessage` bridge back to this tab. No API key
/// is required — Daum's postcode embed script is free to use for address
/// lookup (unlike Kakao's map/geocoding APIs, which do need a key).
class AddressSearchService {
  Future<AddressSearchResult?> search() {
    final completer = Completer<AddressSearchResult?>();
    Timer? closeWatcher;
    late final JSFunction listener;

    void cleanup() {
      web.window.removeEventListener('message', listener);
      closeWatcher?.cancel();
    }

    listener = ((web.Event event) {
      final data = (event as web.MessageEvent).data.dartify();
      if (data is Map && data['source'] == 'aquaconnect-postcode') {
        final address = data['address'] as String?;
        final zonecode = data['zonecode'] as String?;
        cleanup();
        if (!completer.isCompleted) {
          completer.complete(address == null || address.isEmpty
              ? null
              : AddressSearchResult(address: address, zonecode: zonecode));
        }
      }
    }).toJS;

    web.window.addEventListener('message', listener);
    final popup = web.window.open('/postcode.html', 'aquaconnect-postcode', 'width=480,height=620');

    if (popup == null) {
      cleanup();
      completer.complete(null);
      return completer.future;
    }

    closeWatcher = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (popup.closed) {
        cleanup();
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    return completer.future;
  }
}
