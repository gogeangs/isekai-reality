part of '../app_controller.dart';

/// 묶음 65 #255: 우리 영지 하나 (서버가 준 그대로. 번영도는 다음 단계까지 몇 할인지만)
class EstateDev {
  const EstateDev({
    required this.estate,
    required this.stage,
    required this.progress,
    required this.slots,
    required this.fac,
    required this.special,
    required this.policy,
    required this.canPolicy,
    required this.request,
  });

  factory EstateDev.fromJson(Map<String, dynamic> j) {
    final r = (j['request'] as Map?) ?? const {};
    return EstateDev(
      estate: '${j['estate']}',
      stage: (j['stage'] as num?)?.toInt() ?? 0,
      progress: (j['progress'] as num?)?.toDouble() ?? 0,
      slots: (j['slots'] as num?)?.toInt() ?? 3,
      fac: {
        for (final e in ((j['fac'] as Map?) ?? const {}).entries)
          if ((e.value as num? ?? 0) > 0) '${e.key}': (e.value as num).toInt(),
      },
      special: j['special'] as String?,
      policy: '${j['policy'] ?? 'plenty'}',
      canPolicy: j['canPolicy'] == true,
      request: (
        no: (r['no'] as num?)?.toInt() ?? 0,
        title: '${r['title'] ?? ''}',
        ratio: ((r['goal'] as num?) ?? 0) > 0 ? ((r['steps'] as num?) ?? 0) / (r['goal'] as num) : 0.0,
        goal: (r['goal'] as num?)?.toInt() ?? 0,
        mine: (r['mine'] as num?)?.toInt() ?? 0,
        people: (r['people'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  final String estate;
  final int stage;
  final double progress;
  final int slots;
  final Map<String, int> fac;
  final String? special;
  final String policy;
  final bool canPolicy;
  final ({int no, String title, double ratio, int goal, int mine, int people}) request;

  int get built => fac.length;
}

class EstateDevView {
  const EstateDevView({
    this.estates = const [],
    this.treasury = 0,
    this.matPool = 0,
    this.store = const {},
    this.takeLeft = 0,
    this.donateLeft = 0,
    this.staff = false,
    this.buildGold = const [],
    this.buildMats = const [],
    this.siege = false,
  });

  factory EstateDevView.fromJson(Map<String, dynamic> j) => EstateDevView(
        estates: [
          for (final x in (j['estates'] as List?) ?? const [])
            if (x is Map) EstateDev.fromJson(Map<String, dynamic>.from(x)),
        ],
        treasury: (j['treasury'] as num?)?.toInt() ?? 0,
        matPool: (j['matPool'] as num?)?.toInt() ?? 0,
        store: {
          for (final e in ((j['store'] as Map?) ?? const {}).entries)
            if (Materials.byName('${e.key}') case final m?) m: (e.value as num).toInt(),
        },
        takeLeft: (((j['take'] as Map?) ?? const {})['left'] as num?)?.toInt() ?? 0,
        donateLeft: (j['donateLeft'] as num?)?.toInt() ?? 0,
        staff: j['staff'] == true,
        buildGold: [for (final x in (j['buildGold'] as List?) ?? const []) (x as num).toInt()],
        buildMats: [for (final x in (j['buildMats'] as List?) ?? const []) (x as num).toInt()],
        siege: j['siege'] == true,
      );

  final List<EstateDev> estates;
  final int treasury;
  final int matPool;
  final Map<MaterialId, int> store;
  final int takeLeft;
  final int donateLeft;
  final bool staff;
  final List<int> buildGold;
  final List<int> buildMats;
  final bool siege;

  EstateDev? of(String id) => estates.where((e) => e.estate == id).firstOrNull;
}

extension EstateDevOps on AppController {
  EstateDevView? get estateDev => _estateDev;

  Future<bool> _estateCall(String path, [Map<String, dynamic> body = const {}]) async {
    final j = await _siegeCall(path, body);
    if (j == null) return false;
    final s = j['state'] is Map ? Map<String, dynamic>.from(j['state'] as Map) : j;
    if (s.containsKey('estates')) _estateDev = EstateDevView.fromJson(s);
    _notify();
    return true;
  }

  Future<bool> refreshEstateDev() => _estateCall('/siege/estate');

  /// 시설 짓기 · 올리기 (길드장 · 부길드장)
  Future<bool> buildFacility(String estate, String kind) async {
    final ok = await _estateCall('/siege/estate/build', {'estate': estate, 'kind': kind});
    if (ok) await refreshErbard();
    return ok;
  }

  /// 재료 기부 → 길드 기부 재료 + 그 영지 번영도 (서버가 하루 상한을 셈)
  Future<bool> donateEstate(String estate, Map<MaterialId, int> mats) async {
    for (final e in mats.entries) {
      if (player.materialCount(e.key) < e.value) return false;
    }
    final ok = await _estateCall('/siege/estate/donate', {
      'estate': estate,
      'mats': {for (final e in mats.entries) e.key.name: e.value},
    });
    if (!ok) return false;
    await _serial(() async {
      final today = await _todayRecord();
      await _save(today.copyWith(
          spends: DailyRecord.addCounts(today.spends, {for (final e in mats.entries) e.key.name: e.value})));
    });
    _notify();
    return true;
  }

  /// 영주의 정책 (공성전이 끝난 뒤 영지별 하나)
  Future<bool> setEstatePolicy(String estate, String kind) =>
      _estateCall('/siege/estate/policy', {'estate': estate, 'kind': kind});

  /// 길드 창고에서 특산물 받기 → 가방 (넘치면 우편함)
  Future<List<String>?> takeSpecialty(MaterialId m, {int n = 1}) async {
    final j = await _siegeCall('/siege/estate/take', {'mat': m.name, 'n': n});
    if (j == null) return null;
    if (j['state'] is Map) _estateDev = EstateDevView.fromJson(Map<String, dynamic>.from(j['state'] as Map));
    final got = <String, int>{
      for (final e in ((j['got'] as Map?) ?? const {}).entries) '${e.key}': (e.value as num).toInt(),
    };
    final out = await _serial(() => _applyGifts(got, over: BagOver.mail, title: '길드 창고'));
    _notify();
    return out;
  }

  /// 기부할 수 있는 재료 (가공 · 특산물 빼고 많은 순)
  List<(MaterialId, int)> get donatableMats {
    final out = [
      for (final e in player.materials.entries)
        if (!Materials.info(e.key).processed && !EstateDevRules.specialties.contains(e.key)) (e.key, e.value),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return out;
  }

  String estateErrorText() => EstateDevRules.errorText(_erbardError ?? '') ?? ErbardRules.errorText(_erbardError ?? '');
}
