import 'dart:async';

import '../../models/member.dart';
import '../../services/api_client.dart';
import '../../services/auth_token_store.dart';
import '../auth_repository.dart';

class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository({required ApiClient apiClient, required this._tokenStore})
      : _api = apiClient {
    _restoreSession();
  }

  final ApiClient _api;
  final AuthTokenStore _tokenStore;
  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> authStateChanges() {
    // Same Stream.multi replay pattern as MockAuthRepository: a screen that
    // starts watching after sign-in already happened must still see the
    // current session immediately, not just future changes.
    return Stream<AuthSession?>.multi((controller) {
      controller.add(_session);
      final sub = _controller.stream.listen(controller.add, onDone: controller.close);
      controller.onCancel = sub.cancel;
    });
  }

  Future<void> _restoreSession() async {
    final token = await _tokenStore.read();
    if (token == null) return;
    try {
      final json = await _api.get('/api/auth/me') as Map<String, dynamic>;
      _session = _sessionFromJson(json);
      _controller.add(_session);
    } catch (_) {
      // Stored token is invalid/expired — fall back to signed-out silently.
      await _tokenStore.clear();
    }
  }

  AuthSession _sessionFromJson(Map<String, dynamic> json) => AuthSession(
        member: Member.fromJson(json['member'] as Map<String, dynamic>),
        organization: Organization.fromJson(json['organization'] as Map<String, dynamic>),
      );

  @override
  Future<void> signIn({required String email, required String password}) async {
    final json = await _api.post('/api/auth/login', body: {'email': email, 'password': password}) as Map<String, dynamic>;
    await _tokenStore.write(json['token'] as String);
    _session = _sessionFromJson(json);
    _controller.add(_session);
  }

  @override
  Future<void> signOut() async {
    await _tokenStore.clear();
    _session = null;
    _controller.add(null);
  }
}
