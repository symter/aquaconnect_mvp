import '../models/invitation.dart';
import '../models/member.dart';

class AuthSession {
  const AuthSession({required this.member, required this.organization});

  final Member member;
  final Organization organization;
}

/// Self-service institute signup: the institute (organization) and its
/// owner account, created and signed in immediately.
class SignupRequest {
  const SignupRequest({
    required this.name,
    required this.email,
    required this.password,
    required this.phone,
    required this.organizationName,
    required this.address,
    required this.termsVersion,
    required this.marketingAgreed,
    this.businessRegNo,
  });

  /// 대표자명.
  final String name;
  final String email;
  final String password;
  final String phone;

  /// 수산질병관리원명.
  final String organizationName;
  final String address;

  /// Optional, digits only.
  final String? businessRegNo;
  final String termsVersion;
  final bool marketingAgreed;

  Map<String, dynamic> toJson() => {
        'account': {'name': name, 'email': email, 'password': password, 'phone': phone},
        'organization': {'name': organizationName, 'address': address, 'businessRegNo': businessRegNo},
        // Submitting at all requires both required terms to be checked.
        'terms': {'termsVersion': termsVersion, 'termsAgreed': true, 'privacyAgreed': true, 'marketingAgreed': marketingAgreed},
      };
}

abstract class AuthRepository {
  Stream<AuthSession?> authStateChanges();

  AuthSession? get currentSession;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Re-reads the signed-in member/institute (after a role or 관리원 정보
  /// change) so the app shows the current values.
  Future<void> refreshSession();

  /// Creates the institute + owner account and signs in as that owner.
  Future<void> signUp(SignupRequest request);

  /// False when the email already belongs to an account.
  Future<bool> isEmailAvailable(String email);

  /// Current terms version, recorded with the consent at signup.
  Future<String> termsVersion();

  /// The invite page's details; throws with a user-facing message when the
  /// link is unknown, used, cancelled or expired.
  Future<InvitationInfo> lookupInvitation(String code);

  /// Joins the inviting institute with the invited role and signs in.
  Future<void> acceptInvitation(String code, InviteAcceptRequest request);
}
