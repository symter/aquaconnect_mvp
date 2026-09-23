import '../models/disease_info.dart';
import '../models/farm.dart';
import '../models/member.dart';
import '../models/memo.dart';
import '../models/risk_level.dart';

/// Seed data mirroring the example content baked into the `.dc.html`
/// designs (해강수산질병관리원 · 이동길 · 신일수산 1양식장 등) so the mock
/// build looks identical to the approved mockups.
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

  static final farms = <Farm>[
    Farm(
      id: 'farm-sinil-1',
      orgId: orgId,
      name: '신일수산 1양식장',
      region: '완도',
      address: '완도군 노화읍',
      nearestStationCode: '001',
      nearestStationName: '완도',
      riskLevel: RiskLevel.danger,
      headline: '오늘 폐사 12마리',
      waterTemp: 29.4,
      lastVisitDays: 9,
      assignedMemberName: '이동길',
      ownerContact: '01011112222',
    ),
    Farm(
      id: 'farm-mirae',
      orgId: orgId,
      name: '미래수산',
      region: '완도',
      address: '완도군 금일읍',
      nearestStationCode: '001',
      nearestStationName: '완도',
      riskLevel: RiskLevel.danger,
      headline: '폐사 신고 있음',
      waterTemp: 29.1,
      lastVisitDays: 12,
      assignedMemberName: '이동길',
      ownerContact: '01022223333',
    ),
    Farm(
      id: 'farm-cheonghae',
      orgId: orgId,
      name: '청해양식장',
      region: '해남',
      address: '해남군 화산면',
      nearestStationCode: '002',
      nearestStationName: '해남',
      riskLevel: RiskLevel.warning,
      headline: '섭이 감소 보고',
      waterTemp: 28.6,
      lastVisitDays: 5,
      assignedMemberName: '이동길',
      ownerContact: '01033334444',
    ),
  ];

  static List<Memo> initialMemos(DateTime now) {
    DateTime at(int daysAgo, int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute).subtract(Duration(days: daysAgo));

    return [
      Memo(
        id: 'memo-1',
        orgId: orgId,
        farmId: 'farm-sinil-1',
        farmName: '신일수산 1양식장',
        authorType: MemoAuthorType.institute,
        authorName: '수산질병관리원 · 이동길',
        content: '3수조 유영 둔화 확인. 아가미 색 약간 창백. 내일 재방문해서 확인 필요.',
        tags: const ['3수조', '유영 이상'],
        createdAt: at(0, 14, 32),
        readByFarm: true,
      ),
      Memo(
        id: 'memo-2',
        orgId: orgId,
        farmId: 'farm-sinil-1',
        farmName: '신일수산 1양식장',
        authorType: MemoAuthorType.farm,
        authorName: '어가 · 신일수산 1양식장',
        content: '오늘 아침 폐사 12마리 나왔습니다. 사진 첨부합니다.',
        tags: const ['폐사 12마리'],
        createdAt: at(0, 8, 5),
        photoCount: 1,
        readByFarm: true,
      ),
      Memo(
        id: 'memo-3',
        orgId: orgId,
        authorType: MemoAuthorType.institute,
        authorName: '수산질병관리원 · 이동길',
        content: 'GLOBEFISH 뉴스 확인 — 동남아 AHPND 확산, 국내 영향 여부 계속 모니터링.',
        tags: const [],
        createdAt: at(1, 19, 40),
      ),
      Memo(
        id: 'memo-4',
        orgId: orgId,
        farmId: 'farm-mirae',
        farmName: '미래수산',
        authorType: MemoAuthorType.farm,
        authorName: '어가 · 미래수산',
        content: '2수조 폐사 신고, 수면 근처 유영 개체 다수 관찰됨.',
        tags: const ['폐사 6마리'],
        createdAt: at(1, 7, 40),
        photoCount: 1,
        readByFarm: true,
      ),
      Memo(
        id: 'memo-5',
        orgId: orgId,
        farmId: 'farm-cheonghae',
        farmName: '청해양식장',
        authorType: MemoAuthorType.institute,
        authorName: '수산질병관리원 · 이동길',
        content: '섭이 감소 확인, 수온 상승 지속 시 재방문 필요.',
        tags: const [],
        createdAt: at(2, 16, 12),
        readByFarm: true,
      ),
    ];
  }

  static final diseaseInfo = <DiseaseInfo>[
    DiseaseInfo(
      id: 'disease-1',
      scope: DiseaseInfoScope.domestic,
      species: '넙치',
      title: '전남 해역 넙치 에드워드시엘라증 산발 신고',
      source: '국립수산과학원',
      publishedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    DiseaseInfo(
      id: 'disease-2',
      scope: DiseaseInfoScope.overseas,
      species: '새우',
      title: '동남아 새우 AHPND 확산 — 국내 어종 무관',
      source: 'GLOBEFISH',
      publishedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    DiseaseInfo(
      id: 'disease-3',
      scope: DiseaseInfoScope.overseas,
      species: '연어',
      title: '노르웨이 연어 ISA 바이러스 발생 보고',
      source: 'FAO FishStat',
      publishedAt: DateTime.now().subtract(const Duration(days: 5)),
    ),
  ];
}
