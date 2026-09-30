import 'package:flutter/material.dart';

/// 수산질병관리원 내부에서만 공유하는 월별 리포트.
///
/// 어가에 보내는 관리 리포트(`SharedReportView`)와 달리 기관 구성원만
/// 본다. 지금은 서버 API가 없어 [MonthlyReportExample]의 예시 데이터로
/// 그린다.
enum MonthlyEventType {
  patrol('예찰', Color(0xFF2A78D6)),
  delivery('배달', Color(0xFFEB6834)),
  diag('바이러스 진단', Color(0xFF1BAF7A)),
  exam('검사', Color(0xFFEDA100)),
  safety('안전성 검사', Color(0xFFE87BA4)),
  vacc('접종', Color(0xFF008300)),
  water('DO·pH 측정', Color(0xFF4A3AA7));

  const MonthlyEventType(this.label, this.color);

  final String label;
  final Color color;

  /// 같은 날 기록을 보여 주는 순서.
  static const displayOrder = [diag, exam, safety, vacc, patrol, delivery, water];

  /// 캘린더에서 직접 추가할 수 있는 종류.
  static const addable = [patrol, delivery, diag, exam, safety, vacc];
}

enum MonthlyFarmStatus {
  urgent('긴급'),
  action('조치 필요'),
  normal('정상');

  const MonthlyFarmStatus(this.label);
  final String label;
}

class MonthlyFarm {
  const MonthlyFarm({required this.id, required this.sea, required this.fish, required this.status, required this.next});

  final String id;
  final String sea;
  final String fish;
  final MonthlyFarmStatus status;
  final String next;
}

class SeaSeries {
  const SeaSeries({required this.temps, required this.salinities});

  /// [MonthlyReport.weeks] 순서의 주간 값.
  final List<double> temps;
  final List<double> salinities;
}

/// DO 5 mg/L 이상, pH 7.5~8.5를 기준으로 판정한다.
bool isDoOk(double v) => v >= 5;
bool isPhOk(double v) => v >= 7.5 && v <= 8.5;
bool isWaterOk(double doValue, double ph) => isDoOk(doValue) && isPhOk(ph);

class WaterTank {
  const WaterTank({required this.farm, required this.tank, required this.days, required this.doValues, required this.phValues});

  final String farm;
  final String tank;
  final List<int> days;
  final List<double> doValues;
  final List<double> phValues;

  String get key => '$farm|$tank';
}

/// 한 건의 업무 기록. 종류마다 쓰는 필드가 달라서 [type]에 맞는 필드만
/// 채운다.
class MonthlyEvent {
  const MonthlyEvent({
    required this.day,
    required this.farm,
    required this.type,
    this.tank,
    this.note,
    this.item,
    this.qty,
    this.amount,
    this.status,
    this.test,
    this.micro,
    this.disease,
    this.result,
    this.kind,
    this.subject,
    this.drug,
    this.count,
    this.fee,
    this.doValue,
    this.ph,
    this.custom = false,
  });

  final int day;
  final String farm;
  final MonthlyEventType type;
  final String? tank;
  final String? note;
  // 배달
  final String? item;
  final String? qty;
  final int? amount;
  final String? status;
  // 바이러스 진단
  final String? test;
  final String? micro;
  final String? disease;
  final String? result;
  // 검사
  final String? kind;
  final String? subject;
  // 안전성 검사·접종
  final String? drug;
  final int? count;
  final int? fee;
  // DO·pH
  final double? doValue;
  final double? ph;

  /// 캘린더에서 "내용" 한 줄로 직접 추가한 기록.
  final bool custom;

  bool get isPendingDelivery => type == MonthlyEventType.delivery && status == '미정';
}

class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.today,
    required this.farms,
    required this.weeks,
    required this.sea,
    required this.events,
    required this.tanks,
  });

  final int year;
  final int month;

  /// 기준일(해당 월의 일). 이후 날짜의 기록은 "예정"으로 표시한다.
  final int today;
  final List<MonthlyFarm> farms;
  final List<int> weeks;
  final Map<String, SeaSeries> sea;

  /// DO·pH 측정은 [tanks]에서 따로 펼쳐 넣지 않는다 — [allEvents] 참고.
  final List<MonthlyEvent> events;
  final List<WaterTank> tanks;

  int get daysInMonth => DateUtils.getDaysInMonth(year, month);

  /// 업무 기록 + 수조별 DO·pH 측정을 한 목록으로.
  List<MonthlyEvent> allEvents(List<MonthlyEvent> records) => [
        ...records,
        for (final t in tanks)
          for (var i = 0; i < t.days.length; i++)
            MonthlyEvent(
              day: t.days[i],
              farm: t.farm,
              type: MonthlyEventType.water,
              tank: t.tank,
              doValue: t.doValues[i],
              ph: t.phValues[i],
            ),
      ];

  bool isPlanned(MonthlyEvent e) => e.day > today || e.isPendingDelivery;
}

/// 첨부된 `수산질병관리원_월별리포트.html`의 예시 데이터 (2026년 9월).
class MonthlyReportExample {
  MonthlyReportExample._();

  static const september2026 = MonthlyReport(
    year: 2026,
    month: 9,
    today: 28,
    weeks: [1, 7, 14, 21, 28],
    farms: [
      MonthlyFarm(id: '태안 A', sea: '서해', fish: '넙치', status: MonthlyFarmStatus.action, next: '출하 10/2 (D-4)'),
      MonthlyFarm(id: '보령 B', sea: '서해', fish: '우럭', status: MonthlyFarmStatus.action, next: '입식 9/20 (D+8), 검사 기한 10/4'),
      MonthlyFarm(id: '완도 C', sea: '남해', fish: '전복', status: MonthlyFarmStatus.action, next: '출하 10/5 (D-7)'),
      MonthlyFarm(id: '진도 D', sea: '남해', fish: '넙치', status: MonthlyFarmStatus.urgent, next: '입식 9/25 (D+3), 검사 기한 10/9'),
      MonthlyFarm(id: '통영 E', sea: '남해', fish: '참돔', status: MonthlyFarmStatus.urgent, next: '출하 9/30 (D-2)'),
      MonthlyFarm(id: '거제 F', sea: '남해', fish: '넙치', status: MonthlyFarmStatus.action, next: '입식 9/12 (D+16), 검사 완료'),
      MonthlyFarm(id: '성산 G', sea: '제주', fish: '넙치', status: MonthlyFarmStatus.normal, next: '출하 10/8 (D-10)'),
      MonthlyFarm(id: '포항 H', sea: '동해', fish: '강도다리', status: MonthlyFarmStatus.urgent, next: '입식 9/10 (D+18), 검사 기한 9/24'),
    ],
    sea: {
      '서해': SeaSeries(temps: [25.6, 24.5, 23.3, 22.0, 21.4], salinities: [30.4, 30.7, 30.9, 31.0, 31.2]),
      '남해': SeaSeries(temps: [26.4, 25.6, 24.4, 23.5, 23.1], salinities: [31.8, 32.0, 32.1, 32.3, 32.4]),
      '제주': SeaSeries(temps: [27.0, 26.3, 25.2, 24.2, 24.0], salinities: [33.1, 33.2, 33.3, 33.4, 33.5]),
      '동해': SeaSeries(temps: [25.1, 24.2, 23.1, 22.3, 21.8], salinities: [33.6, 33.7, 33.8, 33.8, 33.9]),
    },
    events: [
      // 예찰
      MonthlyEvent(day: 1, farm: '태안 A', type: MonthlyEventType.patrol, tank: '1동-01', note: '정기 예찰, 이상 없음'),
      MonthlyEvent(day: 2, farm: '진도 D', type: MonthlyEventType.patrol, note: '수온 하강기 대비 사육 밀도 점검'),
      MonthlyEvent(day: 3, farm: '통영 E', type: MonthlyEventType.patrol, tank: '1동-03', note: '참돔 체표 점검, 이상 없음'),
      MonthlyEvent(day: 4, farm: '완도 C', type: MonthlyEventType.patrol, tank: '2동-02', note: '전복 부착 상태 양호'),
      MonthlyEvent(day: 7, farm: '성산 G', type: MonthlyEventType.patrol, tank: '1동-01', note: '접종 전 건강 상태 점검'),
      MonthlyEvent(day: 8, farm: '거제 F', type: MonthlyEventType.patrol, tank: '2동-01', note: '입식 전 수조 소독 확인'),
      MonthlyEvent(day: 9, farm: '포항 H', type: MonthlyEventType.patrol, tank: '2동-04', note: '입식 치어 상태 확인'),
      MonthlyEvent(day: 11, farm: '보령 B', type: MonthlyEventType.patrol, note: '우럭 입식 준비 상담'),
      MonthlyEvent(day: 15, farm: '태안 A', type: MonthlyEventType.patrol, tank: '1동-02', note: '아가미 점검, 기생충 소량 의심'),
      MonthlyEvent(day: 16, farm: '진도 D', type: MonthlyEventType.patrol, tank: '3동-01', note: '섭이 저하 관찰, 수질 추적 권고'),
      MonthlyEvent(day: 18, farm: '포항 H', type: MonthlyEventType.patrol, tank: '2동-04', note: '소량 폐사 확인 → 진단 의뢰'),
      MonthlyEvent(day: 21, farm: '통영 E', type: MonthlyEventType.patrol, tank: '1동-03', note: '출하 전 상태 점검'),
      MonthlyEvent(day: 22, farm: '진도 D', type: MonthlyEventType.patrol, tank: '3동-01', note: '출혈 반점 개체 발견 → 시료 채취'),
      MonthlyEvent(day: 25, farm: '거제 F', type: MonthlyEventType.patrol, tank: '2동-01', note: 'pH 상승, 환수 권고'),
      MonthlyEvent(day: 28, farm: '진도 D', type: MonthlyEventType.patrol, tank: '3동-01', note: '방역 방문, 소독·이동 관리 안내'),
      MonthlyEvent(day: 29, farm: '보령 B', type: MonthlyEventType.patrol, note: '입식 검사 일정 협의'),
      MonthlyEvent(day: 30, farm: '성산 G', type: MonthlyEventType.patrol, note: '출하 전 정기 예찰'),
      // 배달
      MonthlyEvent(day: 2, farm: '거제 F', type: MonthlyEventType.delivery, item: '소독제 E', qty: '20L', amount: 90000, status: '완료'),
      MonthlyEvent(day: 5, farm: '통영 E', type: MonthlyEventType.delivery, item: '비타민제 C', qty: '10kg', amount: 30000, status: '완료'),
      MonthlyEvent(day: 9, farm: '포항 H', type: MonthlyEventType.delivery, item: '영양제 F', qty: '15kg', amount: 54000, status: '완료'),
      MonthlyEvent(day: 15, farm: '태안 A', type: MonthlyEventType.delivery, item: '구충제 A', qty: '5L', amount: 90000, status: '완료'),
      MonthlyEvent(day: 19, farm: '보령 B', type: MonthlyEventType.delivery, item: '소독제 E', qty: '10L', amount: 45000, status: '완료'),
      MonthlyEvent(day: 22, farm: '진도 D', type: MonthlyEventType.delivery, item: '비타민제 C', qty: '15kg', amount: 45000, status: '완료'),
      MonthlyEvent(day: 24, farm: '태안 A', type: MonthlyEventType.delivery, item: '비타민제 C', qty: '20kg', amount: 60000, status: '완료'),
      MonthlyEvent(day: 27, farm: '완도 C', type: MonthlyEventType.delivery, item: '항생제 B', qty: '5L', amount: 125000, status: '완료'),
      MonthlyEvent(day: 29, farm: '통영 E', type: MonthlyEventType.delivery, item: '구충제 A', qty: '10L', amount: 180000, status: '미정'),
      // 바이러스 진단
      MonthlyEvent(day: 4, farm: '태안 A', type: MonthlyEventType.diag, tank: '1동-02', test: 'VHSV', micro: '특이 소견 없음', disease: '이상 없음', result: '음성'),
      MonthlyEvent(day: 10, farm: '통영 E', type: MonthlyEventType.diag, tank: '1동-03', test: 'RSIV', micro: '특이 소견 없음', disease: '이상 없음', result: '음성'),
      MonthlyEvent(day: 12, farm: '성산 G', type: MonthlyEventType.diag, tank: '1동-01', test: 'VHSV', micro: '특이 소견 없음', disease: '이상 없음 (접종 전 확인)', result: '음성'),
      MonthlyEvent(day: 18, farm: '포항 H', type: MonthlyEventType.diag, tank: '2동-04', test: 'VHSV', micro: '특이 소견 없음', disease: '이상 없음', result: '음성'),
      MonthlyEvent(day: 23, farm: '진도 D', type: MonthlyEventType.diag, tank: '3동-01', test: 'VHSV', micro: '출혈 반점, 복수', disease: '바이러스 의심', result: '양성'),
      MonthlyEvent(day: 25, farm: '태안 A', type: MonthlyEventType.diag, tank: '1동-02', test: 'VHSV', micro: '아가미 기생충 소량', disease: '기생충성 아가미염(경미)', result: '음성'),
      // 검사
      MonthlyEvent(day: 5, farm: '태안 A', type: MonthlyEventType.exam, kind: '정기', tank: '1동-01', subject: '넙치 표본 10미', result: '외부·해부 이상 없음'),
      MonthlyEvent(day: 11, farm: '통영 E', type: MonthlyEventType.exam, kind: '질병', tank: '1동-03', subject: '참돔 표본 5미', result: '체표 궤양 소수, 세균 배양 비브리오 약양성 → 투약 권고'),
      MonthlyEvent(day: 16, farm: '진도 D', type: MonthlyEventType.exam, kind: '질병', tank: '3동-01', subject: '넙치 표본 5미', result: '섭이 저하, 아가미 약간 창백 → 경과 관찰'),
      MonthlyEvent(day: 18, farm: '포항 H', type: MonthlyEventType.exam, kind: '폐사 원인', tank: '2동-04', subject: '강도다리 폐사어 3미', result: '세균성 소견 없음, 수온 스트레스 추정'),
      MonthlyEvent(day: 20, farm: '거제 F', type: MonthlyEventType.exam, kind: '입식', tank: '2동-01', subject: '넙치 치어 30,000미 (입식 9/12, D+8)', result: '외상·해부·현미경 이상 없음'),
      MonthlyEvent(day: 26, farm: '완도 C', type: MonthlyEventType.exam, kind: '정기', tank: '2동-02', subject: '전복 표본 10미', result: '이상 없음'),
      // 안전성 검사
      MonthlyEvent(day: 10, farm: '태안 A', type: MonthlyEventType.safety, tank: '1동-01', drug: '구충제 A', result: '불검출'),
      MonthlyEvent(day: 26, farm: '완도 C', type: MonthlyEventType.safety, tank: '2동-02', drug: '항생제 B', result: '검사 중', note: '출하 10/5'),
      MonthlyEvent(day: 27, farm: '통영 E', type: MonthlyEventType.safety, tank: '1동-03', drug: '구충제 A', result: '검출', note: '휴약 미경과'),
      // 접종
      MonthlyEvent(day: 12, farm: '성산 G', type: MonthlyEventType.vacc, tank: '1동-01', drug: '백신 V1', count: 30000, fee: 3600000, status: '정산 완료'),
      MonthlyEvent(day: 20, farm: '완도 C', type: MonthlyEventType.vacc, tank: '2동-02', drug: '백신 V1', count: 25000, fee: 3000000, status: '정산 완료'),
      MonthlyEvent(day: 29, farm: '포항 H', type: MonthlyEventType.vacc, tank: '2동-04', drug: '항생제 D', count: 12000, fee: 960000, status: '정산 전'),
      MonthlyEvent(day: 30, farm: '태안 A', type: MonthlyEventType.vacc, tank: '1동-02', drug: '백신 V1', count: 18000, fee: 2160000, status: '정산 전'),
    ],
    tanks: [
      WaterTank(farm: '태안 A', tank: '1동-02', days: [3, 7, 10, 14, 17, 21, 24, 28], doValues: [6.8, 6.5, 6.2, 6.0, 5.7, 5.5, 5.4, 5.2], phValues: [8.1, 8.1, 8.0, 8.0, 8.1, 8.0, 8.0, 8.0]),
      WaterTank(farm: '완도 C', tank: '2동-02', days: [3, 7, 10, 14, 17, 21, 24, 28], doValues: [7.0, 6.9, 6.8, 6.6, 6.7, 6.5, 6.4, 6.4], phValues: [8.2, 8.1, 8.2, 8.1, 8.1, 8.1, 8.2, 8.1]),
      WaterTank(farm: '통영 E', tank: '1동-03', days: [3, 7, 10, 14, 17, 21, 24, 28], doValues: [6.4, 6.2, 6.1, 6.0, 5.9, 6.0, 5.9, 5.8], phValues: [8.0, 8.1, 8.0, 8.0, 8.1, 8.0, 8.0, 8.0]),
      WaterTank(farm: '거제 F', tank: '2동-01', days: [2, 6, 9, 13, 16, 20, 23, 27], doValues: [7.1, 6.9, 6.8, 6.5, 6.4, 6.3, 6.1, 6.0], phValues: [8.1, 8.2, 8.2, 8.3, 8.4, 8.5, 8.6, 8.7]),
      WaterTank(farm: '진도 D', tank: '3동-01', days: [2, 6, 9, 13, 16, 20, 23, 27], doValues: [6.2, 6.0, 5.8, 5.5, 5.2, 4.9, 4.6, 4.4], phValues: [8.0, 7.9, 7.8, 7.7, 7.6, 7.5, 7.4, 7.3]),
    ],
  );
}
