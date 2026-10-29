import '../../models/ai_report.dart';
import '../../models/share_link.dart';
import '../../services/api_client.dart';
import '../ai_report_repository.dart';

class RemoteAiReportRepository implements AiReportRepository {
  RemoteAiReportRepository({required ApiClient apiClient}) : _api = apiClient;

  final ApiClient _api;

  List<AiReport> _reports(Object? json) =>
      (json as List<dynamic>).map((e) => AiReport.fromJson(e as Map<String, dynamic>)).toList();

  AiReport _report(Object? json) => AiReport.fromJson(json as Map<String, dynamic>);

  @override
  Future<AiModelStatus> status() async {
    final json = await _api.get('/api/ai-reports/status') as Map<String, dynamic>;
    return AiModelStatus.fromJson(json);
  }

  @override
  Future<List<AiReport>> listForFarm(String farmId) async => _reports(await _api.get('/api/ai-reports/farm/$farmId'));

  @override
  Future<List<AiReport>> listAgency() async => _reports(await _api.get('/api/ai-reports/agency'));

  @override
  Future<AiReport> getReport(String id) async => _report(await _api.get('/api/ai-reports/$id'));

  @override
  Future<AiReport> generate({
    required String farmId,
    required String from,
    required String to,
    List<String>? memoIds,
    bool includeComments = true,
    String? model,
  }) async =>
      _report(await _api.post('/api/ai-reports/farm/$farmId', body: {
        'from': from,
        'to': to,
        'memoIds': ?memoIds,
        'includeComments': includeComments,
        'model': ?model,
      }));

  @override
  Future<AiReport> generateAgency({required String from, required String to, String? model}) async =>
      _report(await _api.post('/api/ai-reports/agency', body: {'from': from, 'to': to, 'model': ?model}));

  @override
  Future<AiReport> updateBody(String id, String body) async => _report(await _api.put('/api/ai-reports/$id', body: {'body': body}));

  @override
  Future<AiReport> updateFinalOpinion(String id, String opinion) async =>
      _report(await _api.put('/api/ai-reports/$id', body: {'finalOpinion': opinion}));

  @override
  Future<AiReport> setConfirmed(String id, {required bool confirmed}) async =>
      _report(await _api.post('/api/ai-reports/$id/${confirmed ? 'confirm' : 'unconfirm'}'));

  @override
  Future<({AiReport report, ShareLink link})> send(String id) async {
    final json = await _api.post('/api/ai-reports/$id/send') as Map<String, dynamic>;
    return (report: _report(json['report']), link: ShareLink.fromJson(json['shareLink'] as Map<String, dynamic>));
  }

  @override
  Future<AiReport> revise(String id) async => _report(await _api.post('/api/ai-reports/$id/revise'));

  @override
  Future<List<AiReportVersion>> versions(String id) async {
    final json = await _api.get('/api/ai-reports/$id/versions') as List<dynamic>;
    return json.map((e) => AiReportVersion.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<AiMemoReview> memoReview({required String from, required String to, String? farmId}) async {
    final json = await _api.get('/api/ai-reports/memo-review', query: {'from': from, 'to': to, 'farmId': ?farmId});
    return AiMemoReview.fromJson(json as Map<String, dynamic>);
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete('/api/ai-reports/$id');
  }

  @override
  Future<List<AiReport>> listSent(String token) async => _reports(await _api.get('/api/public/reports/$token/ai-reports'));

  @override
  Future<AiReport?> getSent(String token, String reportId) async {
    try {
      return _report(await _api.get('/api/public/reports/$token/ai-reports/$reportId'));
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
