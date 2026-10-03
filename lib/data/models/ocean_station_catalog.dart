// Official coordinates for every NIFS RISA (실시간 어장정보) observation
// station, taken from the NIFS OpenAPI station-metadata endpoint
// (`OpenAPI_json?id=risaCode`, fetched 2026-09-28). The realtime
// `risaList` feed the app reads temperatures from carries no coordinates,
// so they're recorded here and joined by station code.

class OceanStationInfo {
  const OceanStationInfo({
    required this.code,
    required this.name,
    required this.sea,
    required this.latitude,
    required this.longitude,
    required this.layers,
  });

  final String code;
  final String name;

  /// '동해' / '서해' / '남해', as grouped by NIFS.
  final String sea;
  final double latitude;
  final double longitude;

  /// Which depths this station measures ('표층'/'중층'/'저층').
  final List<String> layers;
}

const oceanStationCatalog = <String, OceanStationInfo>{
  'bgna3': OceanStationInfo(code: 'bgna3', name: '강릉', sea: '동해', latitude: 37.799, longitude: 128.9492, layers: ['표층', '중층', '저층']),
  'fgg4c': OceanStationInfo(code: 'fgg4c', name: '거제 가배', sea: '남해', latitude: 34.7851, longitude: 128.5664, layers: ['표층']),
  'gi086': OceanStationInfo(code: 'gi086', name: '거제 일운', sea: '남해', latitude: 34.8038, longitude: 128.7094, layers: ['표층']),
  'fggo3': OceanStationInfo(code: 'fggo3', name: '고성 가진', sea: '동해', latitude: 38.3681, longitude: 128.5239, layers: ['표층', '중층', '저층']),
  'fgsj3': OceanStationInfo(code: 'fgsj3', name: '고흥 소록도', sea: '남해', latitude: 34.5049, longitude: 127.1228, layers: ['표층']),
  'fghe8': OceanStationInfo(code: 'fghe8', name: '구룡포 하정', sea: '동해', latitude: 35.9607, longitude: 129.5497, layers: ['표층']),
  'egsi4': OceanStationInfo(code: 'egsi4', name: '군산 신시도', sea: '서해', latitude: 35.8168, longitude: 126.4422, layers: ['표층']),
  'bgj8a': OceanStationInfo(code: 'bgj8a', name: '기장', sea: '동해', latitude: 35.187, longitude: 129.227, layers: ['표층', '중층', '저층']),
  'eng5c': OceanStationInfo(code: 'eng5c', name: '남해 강진', sea: '남해', latitude: 34.8746, longitude: 127.9522, layers: ['표층']),
  'fnm5b': OceanStationInfo(code: 'fnm5b', name: '남해 미조', sea: '남해', latitude: 34.7255, longitude: 128.0497, layers: ['표층', '중층']),
  'emp67': OceanStationInfo(code: 'emp67', name: '목포', sea: '서해', latitude: 34.7892, longitude: 126.3653, layers: ['표층']),
  'fbn69': OceanStationInfo(code: 'fbn69', name: '백령도', sea: '서해', latitude: 37.9505, longitude: 124.7295, layers: ['표층']),
  'fbsp5': OceanStationInfo(code: 'fbsp5', name: '보령 소도', sea: '서해', latitude: 36.3969, longitude: 126.4328, layers: ['표층']),
  'bsc87': OceanStationInfo(code: 'bsc87', name: '삼척', sea: '동해', latitude: 37.3023, longitude: 129.3127, layers: ['표층', '중층', '저층']),
  'sj086': OceanStationInfo(code: 'sj086', name: '서산 지곡', sea: '서해', latitude: 36.8935, longitude: 126.3524, layers: ['표층']),
  'fsch6': OceanStationInfo(code: 'fsch6', name: '서산 창리', sea: '서해', latitude: 36.6163, longitude: 126.3717, layers: ['표층', '중층']),
  'ejj47': OceanStationInfo(code: 'ejj47', name: '서제주', sea: '남해', latitude: 33.3104, longitude: 126.164, layers: ['표층']),
  'byy87': OceanStationInfo(code: 'byy87', name: '양양', sea: '동해', latitude: 38.0808, longitude: 128.6998, layers: ['표층', '중층', '저층']),
  'km001': OceanStationInfo(code: 'km001', name: '여수 신월', sea: '남해', latitude: 34.687, longitude: 127.708, layers: ['표층']),
  'byd8a': OceanStationInfo(code: 'byd8a', name: '영덕', sea: '동해', latitude: 36.5737, longitude: 129.437, layers: ['표층', '중층', '저층']),
  'fwgf1': OceanStationInfo(code: 'fwgf1', name: '완도 가교', sea: '남해', latitude: 34.4347, longitude: 126.8083, layers: ['표층', '중층']),
  'fwyo5': OceanStationInfo(code: 'fwyo5', name: '완도 감목', sea: '남해', latitude: 34.342, longitude: 127.0101, layers: ['표층']),
  'wk094': OceanStationInfo(code: 'wk094', name: '완도 금일', sea: '남해', latitude: 34.3786, longitude: 127.0654, layers: ['표층']),
  'wn087': OceanStationInfo(code: 'wn087', name: '완도 노화도', sea: '남해', latitude: 34.2214, longitude: 126.5414, layers: ['표층']),
  'fwdo5': OceanStationInfo(code: 'fwdo5', name: '완도 대창', sea: '남해', latitude: 34.3825, longitude: 126.7364, layers: ['표층']),
  'fwdf1': OceanStationInfo(code: 'fwdf1', name: '완도 동백', sea: '남해', latitude: 34.3275, longitude: 127.035, layers: ['표층', '중층']),
  'fwmg3': OceanStationInfo(code: 'fwmg3', name: '완도 망남', sea: '남해', latitude: 34.3013, longitude: 126.768, layers: ['표층', '중층']),
  'fwbf1': OceanStationInfo(code: 'fwbf1', name: '완도 백도', sea: '남해', latitude: 34.1636, longitude: 126.6269, layers: ['표층', '중층']),
  'fwso5': OceanStationInfo(code: 'fwso5', name: '완도 사동', sea: '남해', latitude: 34.3373, longitude: 127.0837, layers: ['표층']),
  'fwih6': OceanStationInfo(code: 'fwih6', name: '완도 일정', sea: '남해', latitude: 34.3674, longitude: 126.9941, layers: ['표층']),
  'wc001': OceanStationInfo(code: 'wc001', name: '완도 청산', sea: '남해', latitude: 34.1698, longitude: 126.8547, layers: ['표층']),
  'br001': OceanStationInfo(code: 'br001', name: '태안 고남', sea: '서해', latitude: 36.4158, longitude: 126.4333, layers: ['표층']),
  'ftdk5': OceanStationInfo(code: 'ftdk5', name: '태안 대야도', sea: '서해', latitude: 36.4808, longitude: 126.4202, layers: ['표층', '중층']),
  'ftpk5': OceanStationInfo(code: 'ftpk5', name: '태안 파도리', sea: '서해', latitude: 36.7123, longitude: 126.147, layers: ['표층', '중층']),
  'tb087': OceanStationInfo(code: 'tb087', name: '통영 비산도', sea: '남해', latitude: 34.8082, longitude: 128.4951, layers: ['표층', '중층']),
  'ty005': OceanStationInfo(code: 'ty005', name: '통영 사량', sea: '남해', latitude: 34.8022, longitude: 128.2463, layers: ['표층']),
  'ftsj3': OceanStationInfo(code: 'ftsj3', name: '통영 수월', sea: '남해', latitude: 34.8222, longitude: 128.345, layers: ['표층']),
  'ty004': OceanStationInfo(code: 'ty004', name: '통영 영운', sea: '남해', latitude: 34.7904, longitude: 128.4293, layers: ['표층']),
  'ftp4c': OceanStationInfo(code: 'ftp4c', name: '통영 풍화', sea: '남해', latitude: 34.8348, longitude: 128.3353, layers: ['표층', '중층']),
  'fth59': OceanStationInfo(code: 'fth59', name: '통영 학림', sea: '남해', latitude: 34.7498, longitude: 128.4151, layers: ['표층', '중층', '저층']),
  'fjh5a': OceanStationInfo(code: 'fjh5a', name: '해남 임하', sea: '서해', latitude: 34.6069, longitude: 126.2672, layers: ['표층']),
};
