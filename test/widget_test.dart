import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';
import 'package:isekai_reality/app_controller.dart';

void main() {
  testWidgets('예시 모드로 앱이 열리고 상태창에 레벨이 보인다', (tester) async {
    final controller =
        AppController.demo(clock: () => DateTime(2026, 11, 8, 14));
    await tester.pumpWidget(IsekaiRealityApp(controller: controller));
    await controller.init();
    await tester.pump();

    // 레벨 줄과 왼쪽 위 프로필 버튼
    expect(find.textContaining('Lv.'), findsWidgets);
    expect(find.text('상태'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
  });
}
