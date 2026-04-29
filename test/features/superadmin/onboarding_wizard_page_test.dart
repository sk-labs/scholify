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
      home: OnboardingWizardPage(
        syncEngine: syncEngine,
        validationService: validationService,
        auditLogService: auditLogService,
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
}
