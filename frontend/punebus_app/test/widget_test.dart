import 'package:flutter_test/flutter_test.dart';
import 'package:punebus_app/main.dart';

void main() {
  testWidgets('PuneBus smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PuneBusApp());
    expect(find.text('PuneBus'), findsOneWidget);
  });
}
