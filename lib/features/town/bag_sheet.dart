import '../../app_controller.dart';
import '../../core/rules/rules.dart';
import '../bulssi/spirit_art.dart';

/// 가방 안 물건 그림
String bagIconAsset(AppController c, ShopItem item) =>
    item == ShopItem.bulssiPotion
        ? (c.farewellDone
            ? 'assets/images/item_pet_snack.webp'
            : spiritPotionAsset(c.profile.spiritKind))
        : 'assets/images/${TownRules.info(item).icon}.webp';

String useReason(UseCheck c) => switch (c) {
      UseCheck.ok => '',
      UseCheck.none => '가방에 없어요',
      UseCheck.alreadyFull => '이미 가득해요',
      UseCheck.alreadyActive => '이미 효과가 있어요',
    };

/// 가방 버튼 글자: 물약은 마시기, 나침반은 쓰기, 향은 피우기
String useLabel(ShopItem item, {bool petSnack = false}) =>
    petSnack && item == ShopItem.bulssiPotion ? '주기' : switch (item) {
      ShopItem.expeditionCompass => '쓰기',
      ShopItem.purifyIncense => '피우기',
      ShopItem.raceLens => '감정하기',
      _ => '마시기',
    };

