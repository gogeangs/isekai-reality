// 묶음 41: 잡화상 시험용 기록 (마석 · 금화 · 재료 · 입은 장비 · 산 물건)

import 'package:isekai_reality/app_controller.dart';
import 'package:isekai_reality/core/rules/rules.dart';

import 'smithy_seed.dart';

/// 작은 회복 물약 2개 · 정령 물약(하루 1개, 다 삼) · 원정 나침반을 산 계정
Future<AppController> startShop(
    {int gold = 600, int stones = 12, bool shopped = true}) async {
  final c = await startSmithy(
    gold: gold,
    stones: stones,
    mats: const {
      'ratHide': 7,
      'ironShard': 3,
      'twig': 2,
      'glossyFur': 2,
    },
  );
  if (shopped) {
    await c.buy(ShopItem.healSmall);
    await c.buy(ShopItem.healSmall);
    await c.buy(ShopItem.bulssiPotion);
    await c.buy(ShopItem.expeditionCompass);
  }
  return c;
}
