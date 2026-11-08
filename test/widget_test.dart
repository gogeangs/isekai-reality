import 'package:flutter_test/flutter_test.dart';
import 'package:isekai_reality/app.dart';

void main() {
  testWidgets('앱이 열리고 상태창에 레벨이 보인다', (tester) async {
    await tester.pumpWidget(const IsekaiRealityApp());
    await tester.pump();
    expect(find.textContaining('Lv.'), findsOneWidget);
    expect(find.text('상태'), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
  });
}
