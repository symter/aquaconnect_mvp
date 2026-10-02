import '../models/farm.dart';
import '../models/report.dart';
import '../models/share_link.dart';

class SharedReportBundle {
  const SharedReportBundle({
    required this.farm,
    required this.report,
    required this.link,
    this.organizationName,
    this.assignedMemberPhone,
  });

  final Farm farm;
  final Report report;
  final ShareLink link;

  /// The institute that issued the link, shown as "○○ 제공".
  final String? organizationName;

  /// Phone of the farm's assigned institute member — what the farm owner's
  /// "담당 관리사에게 연락하기" button dials.
  final String? assignedMemberPhone;
}

abstract class ShareLinkRepository {
  Future<ShareLink> createShareLink({required String farmId, required ShareLinkExpiry expiry});

  Future<List<ShareLink>> listShareLinks({String? farmId});

  /// Public lookup used by the unauthenticated `/r/:token` page. Returns
  /// null if the token is unknown, revoked, or expired.
  Future<SharedReportBundle?> resolveToken(String token);

  /// Public: the farm's 문의 memo from the shared report page, delivered to
  /// the institute (memo feed + notification).
  Future<void> sendInquiry({required String token, required String message});
}
