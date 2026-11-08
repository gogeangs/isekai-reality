import '../../core/models/daily_record.dart';
import '../../core/rules/rules.dart';

/// 메인 화면에서 불씨가 할 말을 고른다.
///
/// 대사는 기획 문서의 '불씨 대사 50마디'에서 가져왔다.
/// 원칙: 혼내지 않는다, 무리하게 부추기지 않는다.
class BulssiLines {
  BulssiLines._();

  static String forStatus({
    required DailyRecord today,
    required DungeonGaugeState gauge,
    required DateTime now,
  }) {
    final hour = now.hour;
    final sleep = today.sleepMinutes;

    // 밤 10시 이후에는 쉬라고 말한다
    if (hour >= 22) {
      return '이제 슬슬 쉴 시간이야. 푹 자면 내일 MP가 가득 찰 거야.';
    }

    // 하루 걸음 상한에 닿으면 쉬게 한다
    if (gauge.dailyKeyLimitReached) {
      return '와, 오늘 정말 많이 걸었다! 이제 발도 좀 쉬게 해 주자.';
    }

    // 아침에는 수면 결과
    if (hour < 11) {
      if (sleep == null) {
        return '어젯밤 기록이 안 보여. 건강 앱 연결을 한번 확인해 줄래?';
      }
      if (sleep >= RuleConstants.sleepGoodMinutes) {
        return '좋은 아침! MP가 가득 찼어. 오늘은 뭐든 할 수 있겠는걸?';
      }
      if (sleep >= RuleConstants.sleepOkMinutes) {
        return '좋은 아침! 조금 짧게 잤지만 괜찮아, 천천히 시작하자.';
      }
      return '어젯밤엔 잠이 좀 부족했네. 오늘은 무리하지 말자.';
    }

    // 낮과 저녁에는 걸음과 열쇠
    if (gauge.keysAvailable > 0) {
      return '던전 열쇠가 ${gauge.keysAvailable}개 있어. 미궁 입구에서 열면 보상이 1.5배야!';
    }
    final toGoal = gauge.stepsToGoal;
    if (toGoal != null && toGoal <= 1500) {
      return '목표까지 $toGoal보! 채우면 보너스 열쇠를 하나 더 줄게.';
    }
    final remaining = gauge.stepsPerKey - gauge.stepsIntoNextKey;
    if (remaining <= 1000) {
      return '$remaining보만 더 걸으면 던전 열쇠가 생겨!';
    }
    if (hour >= 15 && today.steps < 1000) {
      return '오늘은 좀 조용한 날이네. 잠깐 바람 쐬러 나갈래?';
    }
    return '오늘도 한 걸음씩. 걸을수록 던전 게이지가 차!';
  }
}
