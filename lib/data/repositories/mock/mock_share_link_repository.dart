import 'dart:math';

import '../../mock/mock_seed.dart';
import '../../models/share_link.dart';
import '../farm_repository.dart';
import '../report_repository.dart';
import '../share_link_repository.dart';

class MockShareLinkRepository implements ShareLinkRepository {
  MockShareLinkRepository({
    required FarmRepository farmRepository,
    required ReportRepository reportRepository,
  })  : _farmRepository = farmRepository,
        _reportRepository = reportRepository;

  final FarmRepository _farmRepository;
  final ReportRepository _reportRepository;

  final List<ShareLink> _links = [];

  static const _tokenChars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final _random = Random();

  String _newToken() => List.generate(6, (_) => _tokenChars[_random.nextInt(_tokenChars.length)]).join();

  @override
  Future<ShareLink> createShareLink({required String farmId, required ShareLinkExpiry expiry}) async {
    final now = DateTime.now();
    final link = ShareLink(
      id: 'link-${now.microsecondsSinceEpoch}',
      farmId: farmId,
      token: _newToken(),
      createdAt: now,
      expiresAt: expiry.expiresAtFrom(now),
    );
    _links.insert(0, link);
    return link;
  }

  @override
  Future<List<ShareLink>> listShareLinks({String? farmId}) async {
    return _links.where((l) => farmId == null || l.farmId == farmId).toList();
  }

  @override
  Future<SharedReportBundle?> resolveToken(String token) async {
    ShareLink? link;
    for (final l in _links) {
      if (l.token == token) {
        link = l;
        break;
      }
    }
    if (link == null || !link.isActive) return null;

    final farm = await _farmRepository.getFarm(link.farmId);
    if (farm == null) return null;

    final report = await _reportRepository.getLatestReport(link.farmId);
    if (report == null) return null;

    return SharedReportBundle(
      farm: farm,
      report: report,
      link: link,
      organizationName: MockSeed.organization.name,
      assignedMemberPhone: MockSeed.currentMember.phone,
    );
  }
}
