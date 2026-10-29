import '../models/ai_report.dart';
import '../models/share_link.dart';

abstract class AiReportRepository {
  /// Whether the server has an AI model configured (never exposes the key).
  Future<AiModelStatus> status();

  /// The farm's AI reports, newest first (summaries — no body).
  Future<List<AiReport>> listForFarm(String farmId);

  /// The institute's 종합 리포트, newest first (summaries — no body).
  Future<List<AiReport>> listAgency();

  Future<AiReport> getReport(String id);

  /// Asks the AI for a new draft from the farm's memos between [from] and
  /// [to] (KST dates, inclusive). [memoIds] null means every memo in range;
  /// [model] null uses the server's default model.
  Future<AiReport> generate({
    required String farmId,
    required String from,
    required String to,
    List<String>? memoIds,
    bool includeComments = true,
    String? model,
  });

  /// A 종합 리포트 over every farm's memos between [from] and [to].
  Future<AiReport> generateAgency({required String from, required String to, String? model});

  Future<AiReport> updateBody(String id, String body);

  /// Sets the 전문가 최종 의견 (empty clears it).
  Future<AiReport> updateFinalOpinion(String id, String opinion);

  /// 확정 saves a new 판; 확정 취소 (before 발송 only) goes back to draft.
  Future<AiReport> setConfirmed(String id, {required bool confirmed});

  /// 발송 a confirmed farm report. Returns the report and the farm's share
  /// link, where the farm sees it.
  Future<({AiReport report, ShareLink link})> send(String id);

  /// 새 판 만들기: a sent report back to draft. The farm keeps the last sent
  /// 판 until the next 발송.
  Future<AiReport> revise(String id);

  /// Approved 판, newest first.
  Future<List<AiReportVersion>> versions(String id);

  /// 분류 점검 over [from]..[to]; [farmId] null = the whole institute.
  Future<AiMemoReview> memoReview({required String from, required String to, String? farmId});

  Future<void> delete(String id);

  /// What the farm received, via its share link (no login).
  Future<List<AiReport>> listSent(String token);

  Future<AiReport?> getSent(String token, String reportId);
}
