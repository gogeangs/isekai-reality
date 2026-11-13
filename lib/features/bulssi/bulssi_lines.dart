import '../../core/format.dart';
import '../../core/models/daily_record.dart';
import '../../core/models/vitals.dart';
import '../../core/rules/rules.dart';

/// 메인 화면에서 불씨가 할 말을 고른다.
///
/// 대사는 기획 문서의 '불씨 대사 50마디'에서 가져왔다.
/// 원칙: 혼내지 않는다, 무리하게 부추기지 않는다.
class BulssiLines {
  BulssiLines._();

  /// 묶음 25 #166: 원정 중 정령 대사 (단계별). 원정이 없거나 펫이 다 다녀왔으면 null.
  /// 펫 원정이면 정령 대신 「○○이 원정 중이야」
  static String? expedition(Expedition? ex,
      {required String playerName, required DateTime now}) {
    if (ex == null) return null;
    final pet = ex.petName;
    if (ex.petUid != null) {
      if (ex.finished || pet == null) return null;
      return '${josa(pet, '이/가')} 원정 중이야';
    }
    if (ex.finished) return '다녀왔어! 결과를 확인해 볼래?';
    if (ex.decided) {
      return ex.cleared == true
          ? '정화했어! 지금 돌아가는 중이야.'
          : '이번엔 놓쳤어… 돌아가서 다시 준비하자.';
    }
    if (now.difference(ex.startedAt) < const Duration(minutes: 1)) {
      return '${playerName.isEmpty ? '너' : playerName} 대신 내가 원정을 다녀올게. 돌아오면 알려 줄게!';
    }
    final id = Monsters.byName(ex.monster);
    final name = id == null
        ? '몬스터'
        : ModifierRules.displayName(id, [
            for (final m in ex.mods)
              for (final v in ModifierId.values)
                if (v.name == m) v,
          ]);
    return '$name에게 가는 중이야. 조금만 기다려 줘!';
  }

  static String forStatus({
    required DailyRecord today,
    required DungeonGaugeState gauge,
    required DateTime now,
    double hpRatio = 1,
    double mpRatio = 1,
    bool resting = false,
    bool spiritAway = false,
  }) {
    final hour = now.hour;

    final full = hpRatio >= 1 && mpRatio >= 1;

    // 11-10 C4: 가득 찼는데 쉬는 중이면 회복 대신 휴식 보너스를 말한다
    if (resting) {
      return full
          ? '기운은 벌써 가득해. 푹 쉬면 휴식 보너스를 받을 수 있어.'
          : '쉬는 동안 HP와 MP가 조금씩 차오르고 있어. 중간에 일어나도 찬 만큼은 그대로야.';
    }

    // 쓰러지면 쉬자고 한다 (혼내지 않는다)
    if (hpRatio <= 0) {
      return '많이 지쳤구나. 여관에서 쉬거나, 조금 걸으면 HP가 다시 차.';
    }
    if (hpRatio < 0.3) {
      return 'HP가 얼마 안 남았어. 무리하지 말고 여관에 들렀다 가자.';
    }

    // 밤 10시 이후에는 쉬라고 말한다
    if (hour >= 22) {
      return '오늘 하루 수고했어. 여관에서 쉬면 내일 아침엔 기운이 가득할 거야.';
    }

    // 여관에서 다 쉬고 가득 찬 날
    if (full && today.rested) return '다 회복했어! 이제 나가볼까?';

    // 하루 걸음 상한에 닿으면 쉬게 한다
    if (gauge.dailyKeyLimitReached) {
      return '와, 오늘 정말 많이 걸었다! 이제 발도 좀 쉬게 해 주자.';
    }

    if (spiritAway) {
      return '원정을 다녀올게. 돌아오면 알려 줄게!';
    }

    // 걸음과 열쇠
    if (gauge.keysAvailable > 0) {
      return '던전 열쇠가 ${gauge.keysAvailable}개 있어. 던전을 열어 볼까?';
    }
    final toGoal = gauge.stepsToGoal;
    if (toGoal != null && toGoal <= 1500) {
      return '목표까지 $toGoal보! 채우면 보너스 열쇠를 하나 더 줄게.';
    }
    final remaining = gauge.stepsPerKey - gauge.stepsIntoNextKey;
    if (remaining <= 1000) {
      return '$remaining보만 더 걸으면 던전 열쇠가 생겨!';
    }
    if (hour < 11) return '좋은 아침! 오늘도 한 걸음씩 가 보자.';
    if (hour >= 15 && today.steps < 1000) {
      return '오늘은 좀 조용한 날이네. 바쁘면 나를 원정 보내도 돼!';
    }
    return '오늘도 한 걸음씩. 걸을수록 던전 게이지가 차!';
  }
}
