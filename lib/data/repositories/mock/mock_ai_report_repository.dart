import '../../models/ai_report.dart';
import '../../models/share_link.dart';
import '../ai_report_repository.dart';

/// Mock mode has no AI model behind it. Per the symterAI rule, an
/// unconnected AI is shown as 미연결 — never answered with a fake draft.
class MockAiReportRepository implements AiReportRepository {
  static const _notConnected = '목업 모드에서는 AI가 연결되어 있지 않습니다.';

  @override
  Future<AiModelStatus> status() async => const AiModelStatus(configured: false, model: '', note: _notConnected);

  @override
  Future<List<AiReport>> listForFarm(String farmId) async => const [];

  @override
  Future<List<AiReport>> listAgency() async => const [];

  @override
  Future<AiReport> getReport(String id) => throw Exception('AI 리포트를 찾을 수 없습니다.');

  @override
  Future<AiReport> generate({
    required String farmId,
    required String from,
    required String to,
    List<String>? memoIds,
    bool includeComments = true,
    String? model,
  }) =>
      throw Exception(_notConnected);

  @override
  Future<AiReport> generateAgency({required String from, required String to, String? model}) => throw Exception(_notConnected);

  @override
  Future<AiReport> updateBody(String id, String body) => throw Exception(_notConnected);

  @override
  Future<AiReport> updateFinalOpinion(String id, String opinion) => throw Exception(_notConnected);

  @override
  Future<AiReport> setConfirmed(String id, {required bool confirmed}) => throw Exception(_notConnected);

  @override
  Future<({AiReport report, ShareLink link})> send(String id) => throw Exception(_notConnected);

  @override
  Future<AiReport> revise(String id) => throw Exception(_notConnected);

  @override
  Future<List<AiReportVersion>> versions(String id) async => const [];

  @override
  Future<AiMemoReview> memoReview({required String from, required String to, String? farmId}) async =>
      const AiMemoReview(total: 0, unclassified: 0, deathsWithoutCount: 0, items: []);

  @override
  Future<void> delete(String id) async {}

  @override
  Future<List<AiReport>> listSent(String token) async => const [];

  @override
  Future<AiReport?> getSent(String token, String reportId) async => null;
}
