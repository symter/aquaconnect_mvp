import 'dart:async';

import '../../mock/mock_seed.dart';
import '../../models/invitation.dart';
import '../../models/member.dart';
import '../auth_repository.dart';

/// In-memory auth for local/demo runs. Any non-empty email/password pair
/// signs in as the seeded 해강수산질병관리원 · 이동길 member.
class MockAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthSession?>.broadcast();
  AuthSession? _session;

  @override
  AuthSession? get currentSession => _session;

  @override
  Stream<AuthSession?> authStateChanges() {
    // Stream.multi runs its callback once per listener, so every new
    // subscriber (e.g. a screen mounted after sign-in already happened)
    // immediately gets the current session instead of only future changes
    // — matching how Supabase's own onAuthStateChange replays state.
    return Stream.multi((controller) {
      controller.add(_session);
      final sub = _controller.stream.listen(controller.add, onDone: controller.close);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    if (email.trim().isEmpty || password.trim().isEmpty) {
      throw Exception('이메일과 비밀번호를 입력해주세요.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _session = const AuthSession(
      member: MockSeed.currentMember,
      organization: MockSeed.organization,
    );
    _controller.add(_session);
  }

  @override
  Future<void> refreshSession() async {}

  /// Mock mode has no shared invite store, so any code shows a demo invite.
  @override
  Future<InvitationInfo> lookupInvitation(String code) async => InvitationInfo(
        orgName: MockSeed.organization.name,
        role: MemberRole.staff,
        inviterName: MockSeed.currentMember.name,
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        termsVersion: 'mock',
      );

  @override
  Future<void> acceptInvitation(String code, InviteAcceptRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _session = AuthSession(
      member: Member(
        id: 'member-${DateTime.now().microsecondsSinceEpoch}',
        orgId: MockSeed.orgId,
        name: request.name,
        role: MemberRole.staff,
        phone: request.phone,
      ),
      organization: MockSeed.organization,
    );
    _controller.add(_session);
  }

  /// Mock mode: signs in as the new owner of a new in-memory institute.
  @override
  Future<void> signUp(SignupRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final orgId = 'org-${DateTime.now().microsecondsSinceEpoch}';
    _session = AuthSession(
      member: Member(id: 'member-$orgId', orgId: orgId, name: request.name, role: MemberRole.owner, phone: request.phone),
      organization: Organization(id: orgId, name: request.organizationName),
    );
    _controller.add(_session);
  }

  @override
  Future<bool> isEmailAvailable(String email) async => true;

  @override
  Future<String> termsVersion() async => 'mock';

  @override
  Future<void> signOut() async {
    _session = null;
    _controller.add(null);
  }
}
