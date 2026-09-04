import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:salah_focus/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app starts without requesting permissions immediately', (WidgetTester tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('SalahFocus'), findsWidgets);
  });
}
