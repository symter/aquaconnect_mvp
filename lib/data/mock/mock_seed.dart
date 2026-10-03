import '../models/disease_info.dart';
import '../models/farm.dart';
import '../models/member.dart';
import '../models/memo.dart';

/// Mock-mode identity: the org and signed-in member used when running
/// without a backend. Everything else starts empty.
class MockSeed {
  MockSeed._();

  static const orgId = 'org-haegang';

  static const organization = Organization(id: orgId, name: '해강수산질병관리원');

  static const currentMember = Member(
    id: 'member-leedonggil',
    orgId: orgId,
    name: '이동길',
    role: MemberRole.owner,
  );

  // Starts empty — farms, memos and disease info are only ever what the
  // user enters during a mock-mode session (no demo content).
  static final farms = <Farm>[];

  static List<Memo> initialMemos(DateTime now) => [];

  static const diseaseInfo = <DiseaseInfo>[];
}
