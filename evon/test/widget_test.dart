import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:evon/main.dart';
import 'package:evon/core/services/auth_service.dart';

void main() {
  testWidgets('EVon app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthService()),
        ],
        child: const EVonApp(),
      ),
    );

    // Verify EVon branding appears on login screen
    expect(find.text('EVon'), findsOneWidget);
  });
}
