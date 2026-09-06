import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appimeal/main.dart';

void main() {
  testWidgets('AppiMeal smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AppiMealApp()));
    expect(find.byType(AppiMealApp), findsOneWidget);
  });
}
