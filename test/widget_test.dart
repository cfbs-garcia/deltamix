import 'package:flutter_test/flutter_test.dart';
import 'package:deltamix/main.dart';

void main() {
  testWidgets('DeltamixApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DeltamixApp());
    expect(find.text('DELTAMIX'), findsWidgets);
  });
}
