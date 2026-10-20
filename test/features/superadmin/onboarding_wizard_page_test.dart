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
///
/// NOTE on finders: Flutter's Stepper keeps every step's content and
/// controls in the widget tree (inactive steps are collapsed, not removed),
/// and the page's controlsBuilder derives its labels from the current step,
/// so all four steps render identical control buttons. Tests therefore tap
/// the button at index [stepIndex] (the controls belonging to that step)
/// and use findsWidgets for labels/values that legitimately appear both in
/// an earlier step and in the step-4 summary.
void main() {
  late AppLocalDatabase database;
  late SyncEngine syncEngine;
  late WizardValidationService validationService;
  late AuditLogService auditLogService;
  late PocketbaseGateway gateway;
  late TenantContext tenantContext;
  var dbClosed = false;

  // Drift's StreamQueryStore schedules a cleanup timer after close();
  // closing twice (body + tearDown) or skipping the post-close pump can
  // hang the test or fail it with "Timer is still pending". Close once,
  // then pump to flush the timer — same pattern as the licensing tests.
  Future<void> closeDbOnce(WidgetTester tester) async {
    if (!dbClosed) {
      dbClosed = true;
      await database.close();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(() {
    dbClosed = false;
    database = AppLocalDatabase(executor: NativeDatabase.memory());
    tenantContext = TenantContext();
    gateway = PocketbaseGateway(baseUrl: 'http://test.local');
    // Simulate the signed-in superadmin: AuditLogService requires an
    // actor ID from the gateway's auth model, and tenant creation fails
    // without one ("Cannot log audit entry: actorId is required").
    gateway.setMockAuthModel(const {
      'id': 'superadmin_1',
      'email': 'superadmin@scholify.local',
      'role': 'superadmin',
    });
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
    if (!dbClosed) {
      dbClosed = true;
      try {
        await database.close();
      } catch (_) {}
    }
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

  // The Stepper renders one set of controls per step (4 total).
  // Tap the button at index [stepIndex] to activate that step's controls.
  Future<void> tapStepButton(
      WidgetTester tester, int stepIndex, String label) async {
    final btn = find.widgetWithText(ElevatedButton, label).at(stepIndex);
    await tester.ensureVisible(btn);
    await tester.tap(btn, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  Future<void> tapBackButton(WidgetTester tester, int stepIndex) async {
    final btn = find.widgetWithText(TextButton, 'Back').at(stepIndex);
    await tester.ensureVisible(btn);
    await tester.tap(btn, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  group('OnboardingWizardPage', () {
    testWidgets('displays all 4 steps in order', (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Verify the page title
        expect(find.text('Tenant Onboarding Wizard'), findsOneWidget);

        // Verify step 1 is visible
        expect(find.text('Tenant Identity'), findsOneWidget);
        expect(find.text('School name and tenant ID'), findsOneWidget);

        // Verify other steps are present but not active.
        // 'Owner Email' is also the step-3 field label, so it appears
        // more than once in the tree.
        expect(find.text('License Configuration'), findsOneWidget);
        expect(find.text('Owner Email'), findsWidgets);
        expect(find.text('Confirmation'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('shows validation error for empty school name',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Try to proceed without entering school name
        await tapStepButton(tester, 0, 'Next');

        // Should show error message
        expect(find.text('School name is required.'), findsOneWidget);

        // Should still be on step 1
        expect(find.text('Tenant Identity'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('derives tenant ID from school name',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Enter school name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School 123',
        );
        await tester.pumpAndSettle();

        // Should show derived tenant ID (step-1 preview and the step-4
        // summary row both render it, so it appears more than once).
        expect(find.text('Derived Tenant ID:'), findsOneWidget);
        expect(find.text('test_school_123'), findsWidgets);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('navigates to step 2 after valid step 1',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Enter valid school name
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School',
        );
        await tester.pumpAndSettle();

        // Tap Next (step 1 controls)
        await tapStepButton(tester, 0, 'Next');

        // Should be on step 2
        expect(find.text('Plan and seat limit'), findsOneWidget);
        expect(find.widgetWithText(DropdownButtonFormField<String>, 'Plan'),
            findsOneWidget);
        expect(
            find.widgetWithText(TextFormField, 'Seat Limit'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('shows Back button on step 2', (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Navigate to step 2
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 0, 'Next');

        // Step 2's controls include a Back button (index 1 = step 2's set)
        expect(find.widgetWithText(TextButton, 'Back').at(1), findsOneWidget);

        // Tap Back (step 2 controls)
        await tapBackButton(tester, 1);

        // Should be back on step 1
        expect(find.text('School name and tenant ID'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('validates seat limit is positive',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Navigate to step 2
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 0, 'Next');

        // Enter invalid seat limit
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Seat Limit'),
          '0',
        );
        await tester.pumpAndSettle();

        // Try to proceed
        await tapStepButton(tester, 1, 'Next');

        // Should show error
        expect(
            find.text('Seat limit must be a positive number.'), findsOneWidget);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('validates email format on step 3',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Navigate to step 3
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 0, 'Next');
        await tapStepButton(tester, 1, 'Next');

        // Enter invalid email
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Owner Email'),
          'invalid-email',
        );
        await tester.pumpAndSettle();

        // Try to proceed
        await tapStepButton(tester, 2, 'Next');

        // Should show error (rendered both as the page banner and as the
        // field's validator error, so it appears more than once)
        expect(find.text('Enter a valid email address.'), findsWidgets);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('shows confirmation summary on step 4',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Navigate through all steps
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 0, 'Next');
        await tapStepButton(tester, 1, 'Next');

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Owner Email'),
          'owner@test.com',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 2, 'Next');

        // Should show confirmation summary. Labels and values also appear
        // in the earlier steps' fields/previews, so presence (findsWidgets)
        // is the correct assertion for most of them.
        expect(find.text('Review and create'), findsWidgets);
        expect(find.text('School Name'), findsWidgets);
        expect(find.text('Test School'), findsWidgets);
        expect(find.text('Tenant ID'), findsWidgets);
        expect(find.text('test_school'), findsWidgets);
        expect(find.text('Plan'), findsWidgets);
        expect(find.text('STARTER'), findsWidgets);
        expect(find.text('Seat Limit'), findsWidgets);
        expect(find.text('100'), findsWidgets);
        expect(find.text('Owner Email'), findsWidgets);
        expect(find.text('owner@test.com'), findsWidgets);

        // Should show Create Tenant button
        expect(find.text('Create Tenant'), findsWidgets);
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('disables navigation during save',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // Navigate to step 4
        await tester.enterText(
          find.widgetWithText(TextFormField, 'School Name'),
          'Test School',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 0, 'Next');
        await tapStepButton(tester, 1, 'Next');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Owner Email'),
          'owner@test.com',
        );
        await tester.pumpAndSettle();
        await tapStepButton(tester, 2, 'Next');

        // Tap Create Tenant. Step 4's controls sit below the test
        // surface's fold, so scroll the Stepper first, then tap the one
        // hit-testable Create Tenant button (the current step's).
        await tester.drag(
            find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        final createBtn =
            find.widgetWithText(ElevatedButton, 'Create Tenant').hitTestable();
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pump(); // Start the async operation

        // Should show progress indicator
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Creating tenant...'), findsOneWidget);

        // Wait for the operation to complete
        await tester.pumpAndSettle();
      } finally {
        await closeDbOnce(tester);
      }
    });
  });

  group('5.6 — Step navigation and validation error display', () {
    testWidgets('Next button label changes to "Create Tenant" on final step',
        (WidgetTester tester) async {
      try {
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
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('Back button is absent on step 1',
        (WidgetTester tester) async {
      try {
        await tester.pumpWidget(createTestWidget());

        // On the first step there should be no TextButton labelled "Back"
        expect(
          find.widgetWithText(TextButton, 'Back'),
          findsNothing,
        );
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('validation error clears when user corrects input',
        (WidgetTester tester) async {
      try {
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
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('progress indicator shows "Creating tenant..." text',
        (WidgetTester tester) async {
      try {
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

        // Tap Create Tenant and check the loading state before settling.
        // Step 4's controls are below the fold: scroll first, then tap
        // the one hit-testable button.
        await tester.drag(
            find.byType(ListView).first, const Offset(0, -600));
        await tester.pumpAndSettle();
        final createBtn =
            find.widgetWithText(ElevatedButton, 'Create Tenant').hitTestable();
        expect(createBtn, findsOneWidget);
        await tester.tap(createBtn);
        await tester.pump(); // one frame — async op in flight

        expect(find.text('Creating tenant...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();
      } finally {
        await closeDbOnce(tester);
      }
    });

    testWidgets('confirmation summary shows all five fields',
        (WidgetTester tester) async {
      try {
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

        // All five summary labels must be present (they also appear in
        // earlier steps, hence findsWidgets).
        expect(find.text('School Name'), findsWidgets);
        expect(find.text('Tenant ID'), findsWidgets);
        expect(find.text('Plan'), findsWidgets);
        expect(find.text('Seat Limit'), findsWidgets);
        expect(find.text('Owner Email'), findsWidgets);

        // Values (the derived ID appears in the step-1 preview as well
        // as the summary; the plan appears in the dropdown too).
        expect(find.text('Summary School'), findsWidgets);
        expect(find.text('summary_school'), findsWidgets);
        expect(find.text('STARTER'), findsWidgets);
        expect(find.text('100'), findsWidgets);
        expect(find.text('summary@school.edu'), findsWidgets);
      } finally {
        await closeDbOnce(tester);
      }
    });
  });
}
