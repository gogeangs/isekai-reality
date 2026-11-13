import 'package:flutter/widgets.dart';

/// 튜토리얼이 밝게 비출 곳 (묶음 18 #148). 화면 여기저기에 있는 것을 한곳에서 찾는다.

/// 지도 아래 원정 띠
final GlobalKey tutorialStripKey = GlobalKey(debugLabel: 'tutorialStrip');

/// 아래 메뉴 칸 (상태·가방·지도·마을·도감)
final List<GlobalKey> tutorialNavKeys =
    List.generate(5, (i) => GlobalKey(debugLabel: 'nav$i'));

/// 지도 위 튜토리얼 몬스터 자리 (화면 좌표). 지도가 없거나 아직 모르면 null
final ValueNotifier<Rect?> tutorialMonsterRect = ValueNotifier<Rect?>(null);

/// [key] 가 붙은 위젯의 화면 위 자리
Rect? rectOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
