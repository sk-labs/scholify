import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scholify/core/database/local_database.dart';
import 'package:scholify/core/remote/pocketbase_gateway.dart';
import 'package:scholify/core/services/audit_log_service.dart';
import 'package:scholify/core/services/wizard_validation_service.dart';
import 'package:scholify/core/sync/sync_engine.dart';
import 'package:scholify/core/tenant/tenant_context.dart';
import 'package:scholify/features/superadmin/presentation/onboarding_wizard_page.dart';

/// Widget tests for OnboardingWizardPage
///
/// Feature: scholify-roadmap-tracker
/// Requirements: H1.1, H1.2, H1.3, H1.4, H1.7, H1.8
///
/// Tests the UI behavior of the onboarding wizard including:
/// - Step navigation
/// - Validation error display
/// - Progress indicator during save
void main() {
  late AppLocalDatabase database;
  late SyncEngine syncEngine;
  late WizardValidationService validationService;
  late AuditLogService auditLogService;
  late PocketbaseGateway gateway;
  late TenantContext tenantContext;

  setUp(() {
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    tenantContext = TenantContext();
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    syncEngine = SyncEngine(
      database: database,
      pocketbaseGateway: gateway,
      tenantContext: tenantContext,
    );
    validationService = WizardValidationService(database: database);
    auditLogService = AuditLogService(
      database: database,
      tenantContext: tenantContext,
      gateway: gateway,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Widget createTestWidget() {
    return MaterialApp(
      home: MediaQuery(
        // Give the test a tall viewport so all Stepper steps fit on screen
        data: const MediaQueryData(size: Size(800, 2000)),
        child: OnboardingWizardPage(
          syncEngine: syncEngine,
          validationService: validationService,
          auditLogService: auditLogService,
        ),
      ),
    );
  }

  group('OnboardingWizardPage', () {
    testWidgets('displays all 4 steps in order', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Verify the page title
      expect(find.text('Tenant Onboarding Wizard'), findsOneWidget);

      // Verify step 1 is visible
      expect(find.text('Tenant Identity'), findsOneWidget);
      expect(find.text('School name and tenant ID'), findsOneWidget);

      // Verify other steps are present but not active
      expect(find.text('License Configuration'), findsOneWidget);
      expect(find.text('Owner Email'), findsOneWidget);
      expect(find.text('Confirmation'), findsOneWidget);
    });

    testWidgets('shows validation error for empty school name',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Try to proceed without entering school name
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('School name is required.'), findsOneWidget);

      // Should still be on step 1
      expect(find.text('Tenant Identity'), findsOneWidget);
    });

    testWidgets('derives tenant ID from school name',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Enter school name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School 123',
      );
      await tester.pumpAndSettle();

      // Should show derived tenant ID
      expect(find.text('Derived Tenant ID:'), findsOneWidget);
      expect(find.text('test_school_123'), findsOneWidget);
    });

    testWidgets('navigates to step 2 after valid step 1',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Enter valid school name
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School',
      );
      await tester.pumpAndSettle();

      // Tap Next
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should be on step 2
      expect(find.text('Plan and seat limit'), findsOneWidget);
      expect(find.widgetWithText(DropdownButtonFormField<String>, 'Plan'),
          findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Seat Limit'), findsOneWidget);
    });

    testWidgets('shows Back button on step 2', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to step 2
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show Back button
      expect(find.text('Back'), findsOneWidget);

      // Tap Back
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      // Should be back on step 1
      expect(find.text('School name and tenant ID'), findsOneWidget);
    });

    testWidgets('validates seat limit is positive',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to step 2
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Enter invalid seat limit
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Seat Limit'),
        '0',
      );
      await tester.pumpAndSettle();

      // Try to proceed
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.text('Seat limit must be a positive number.'), findsOneWidget);
    });

    testWidgets('validates email format on step 3',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to step 3
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Enter invalid email
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Email'),
        'invalid-email',
      );
      await tester.pumpAndSettle();

      // Try to proceed
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show error
      expect(find.text('Enter a valid email address.'), findsOneWidget);
    });

    testWidgets('shows confirmation summary on step 4',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate through all steps
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Email'),
        'owner@test.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Should show confirmation summary
      expect(find.text('Review and create'), findsOneWidget);
      expect(find.text('School Name'), findsOneWidget);
      expect(find.text('Test School'), findsOneWidget);
      expect(find.text('Tenant ID'), findsOneWidget);
      expect(find.text('test_school'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('STARTER'), findsOneWidget);
      expect(find.text('Seat Limit'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('Owner Email'), findsOneWidget);
      expect(find.text('owner@test.com'), findsOneWidget);

      // Should show Create Tenant button
      expect(find.text('Create Tenant'), findsOneWidget);
    });

    testWidgets('disables navigation during save',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to step 4
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Test School',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Email'),
        'owner@test.com',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap Create Tenant
      await tester.tap(find.text('Create Tenant'));
      await tester.pump(); // Start the async operation

      // Should show progress indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Creating tenant...'), findsOneWidget);

      // Wait for the operation to complete
      await tester.pumpAndSettle();
    });
  });

  group('5.6 — Step navigation and validation error display', () {
    // The Stepper renders one set of controls per step (4 total).
    // We tap the button at index [stepIndex] to advance that specific step.
    Future<void> tapStepButton(WidgetTester tester, int stepIndex, String label) async {
      final btns = find.widgetWithText(ElevatedButton, label);
      final btn = btns.at(stepIndex);
      await tester.ensureVisible(btn);
      await tester.tap(btn, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    testWidgets('Next button label changes to "Create Tenant" on final step',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Step 1
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Navigation Test School',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 0, 'Next');

      // Step 2 → 3
      await tapStepButton(tester, 1, 'Next');

      // Step 3
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Email'),
        'nav@test.com',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 2, 'Next');

      // On the confirmation step the button must read "Create Tenant"
      final lastButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Create Tenant').first,
      );
      final buttonText = (lastButton.child as Text).data;
      expect(buttonText, equals('Create Tenant'));
    });

    testWidgets('Back button is absent on step 1',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // On the first step there should be no TextButton labelled "Back"
      expect(
        find.widgetWithText(TextButton, 'Back'),
        findsNothing,
      );
    });

    testWidgets('validation error clears when user corrects input',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Trigger validation error by tapping Next with empty name
      await tapStepButton(tester, 0, 'Next');
      expect(find.text('School name is required.'), findsOneWidget);

      // Correct the input
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Fixed School',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 0, 'Next');

      // Error should be gone and we should be on step 2
      expect(find.text('School name is required.'), findsNothing);
      expect(find.text('Plan and seat limit'), findsOneWidget);
    });

    testWidgets('progress indicator shows "Creating tenant..." text',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      // Navigate to final step
      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Progress Test School',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 0, 'Next'); // step 1 → 2
      await tapStepButton(tester, 1, 'Next'); // step 2 → 3

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Email'),
        'progress@test.com',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 2, 'Next'); // step 3 → 4

      // Tap Create Tenant and check the loading state before settling
      final createBtn = find.widgetWithText(ElevatedButton, 'Create Tenant').first;
      await tester.ensureVisible(createBtn);
      await tester.tap(createBtn, warnIfMissed: false);
      await tester.pump(); // one frame — async op in flight

      expect(find.text('Creating tenant...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('confirmation summary shows all five fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.enterText(
        find.widgetWithText(TextFormField, 'School Name'),
        'Summary School',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 0, 'Next'); // step 1 → 2

      // Step 2: keep defaults (starter, 100)
      await tapStepButton(tester, 1, 'Next'); // step 2 → 3

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner Email'),
        'summary@school.edu',
      );
      await tester.pumpAndSettle();
      await tapStepButton(tester, 2, 'Next'); // step 3 → 4

      // All five summary labels must be present
      expect(find.text('School Name'), findsWidgets);
      expect(find.text('Tenant ID'), findsOneWidget);
      expect(find.text('Plan'), findsWidgets);
      expect(find.text('Seat Limit'), findsOneWidget);
      expect(find.text('Owner Email'), findsWidgets);

      // Values
      expect(find.text('Summary School'), findsOneWidget);
      expect(find.text('summary_school'), findsOneWidget);
      expect(find.text('STARTER'), findsOneWidget);
      expect(find.text('100'), findsOneWidget);
      expect(find.text('summary@school.edu'), findsOneWidget);
    });
  });
}
