import 'package:flutter_test/flutter_test.dart';
import 'package:vaia_viajes_conductor_v2/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const VaiaViajesApp());
    expect(find.byType(VaiaViajesApp), findsOneWidget);
  });
}
