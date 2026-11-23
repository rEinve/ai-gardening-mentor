import 'package:flutter_test/flutter_test.dart';

import 'package:ai_gardening_mentor/main.dart';
import 'garden_models_test.dart';

void main() {
  testWidgets('Onboarding -> 7-day cadence -> Triage -> Mentor SSE flow works end-to-end', (tester) async {
    final fake = FakeGardenBackend();
    await tester.pumpWidget(AiGardeningMentorApp(backend: fake));

    // Step 0: Create Account / Login Gate (all services behind auth)
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    // Step 1: Welcome
    expect(find.text('Start My Garden'), findsOneWidget);
    await tester.tap(find.text('Start My Garden'));
    await tester.pumpAndSettle();

    // Step 2: Select Tanzania crops (default 2 selected)
    expect(find.text('What are you growing?'), findsOneWidget);
    await tester.tap(find.textContaining('Continue'));
    await tester.pumpAndSettle();

    // Step 3: Plot details -> Create 7-Day Care Plan
    await tester.ensureVisible(find.text('Create 7-Day Care Plan'));
    await tester.tap(find.text('Create 7-Day Care Plan'));
    await tester.pumpAndSettle();

    // Now on Home 7-day cadence
    expect(find.text("Today's Micro-Habits"), findsOneWidget);
    expect(fake.initPayloads.length, 1);

    // Navigate to Mentor tab and launch Triage from the '+' attachment menu
    await tester.tap(find.text('Mentor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add Photo or Tool'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload Photo from Phone / WhatsApp'));
    await tester.pumpAndSettle();
    expect(find.text('Analyze Photo'), findsOneWidget);
    await tester.tap(find.text('Analyze Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Healthy lower leaf senescence on Tomato.'), findsOneWidget);
    expect(fake.uploadedPaths.length, 1);

    await tester.scrollUntilVisible(find.text('Add Recovery Chore'), 200);
    await tester.tap(find.text('Add Recovery Chore'));
    await tester.pumpAndSettle();
    expect(fake.recoveryDiagnosisIds.length, 1);

    // Navigate back to Mentor and test Mentor SSE streaming
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('When should I water my tomatoes in Dar es Salaam?'));
    await tester.pumpAndSettle();
    expect(
      find.text('Water your Dar es Salaam tomatoes at the root zone before 09:00.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('East-West Seed Knowledge Transfer (EWS-KT)'),
      findsOneWidget,
    );

    await fake.dispose();
  });
}
