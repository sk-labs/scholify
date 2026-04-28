# CSVExportService Implementation

## Overview

The `CSVExportService` is responsible for exporting tenant lists to CSV files with RFC 4180 compliance. This service serializes tenant data to CSV format with proper escaping for commas, quotes, and newlines.

## Requirements Implemented

- **Q2.2**: Generate UTF-8 encoded CSV file with header row and one data row per tenant
- **Q2.3**: CSV file contains the following columns in order:
  - tenant_name
  - tenant_id
  - plan
  - seat_limit
  - is_active
  - license_expires_at
  - owner_email
  - active_students
  - outstanding_amount
- **Q2.5**: If tenant list is empty, generate CSV file containing only the header row
- **Q2.6**: Escape any field value that contains a comma or double-quote character per RFC 4180

## Implementation Details

### Service Class

The service is located at `lib/core/services/csv_export_service.dart` and provides the following methods:

#### `exportTenantList(List<TenantUsageBillingView> tenants)`

Exports a list of tenants to a CSV string. This method:
- Accepts a list of `TenantUsageBillingView` objects
- Fetches owner emails from the `SchoolOwnerEntries` table for each tenant
- Generates a CSV string with proper RFC 4180 escaping
- Returns the CSV content as a string

**Note**: The method is async because it needs to fetch owner emails from the database.

#### `saveCsvFile(String csvContent, {String filename})`

Triggers a platform-specific file save dialog or share sheet. This is a placeholder implementation that needs to be completed with actual platform-specific code using packages like:
- `file_picker` for desktop file save dialogs
- `share_plus` for mobile share sheets
- `dart:html` for web downloads

## RFC 4180 Compliance

The service uses the `csv` package (version 6.0.0) which automatically handles RFC 4180 escaping:
- Fields containing commas are wrapped in double quotes
- Fields containing double quotes have the quotes doubled and are wrapped in double quotes
- Fields containing newlines are wrapped in double quotes

## Testing

Unit tests are located at `test/core/services/csv_export_service_test.dart` and cover:
- Empty tenant list (header only)
- Single tenant export
- Multiple tenants export
- Null value handling
- RFC 4180 escaping (commas, quotes, newlines)
- Owner email lookup

All tests pass successfully.

## Usage Example

```dart
final database = AppLocalDatabase(executor: ...);
final csvService = CSVExportService(database: database);

// Get tenant list from database
final tenants = await database.watchTenantUsageBillingViews().first;

// Export to CSV
final csvContent = await csvService.exportTenantList(tenants);

// Save to file (placeholder - needs implementation)
await csvService.saveCsvFile(csvContent, filename: 'tenants.csv');
```

## Dependencies

- `csv: ^6.0.0` - Added to `pubspec.yaml` for CSV serialization

## Future Enhancements

1. Implement platform-specific file save/share functionality:
   - Add `file_picker` package for desktop
   - Add `share_plus` package for mobile
   - Implement web download using `dart:html`

2. Add progress indicator for large tenant lists

3. Add option to customize CSV columns

4. Add option to filter tenants before export

## Related Files

- Service: `lib/core/services/csv_export_service.dart`
- Tests: `test/core/services/csv_export_service_test.dart`
- Database: `lib/core/database/local_database.dart`
- Requirements: `.kiro/specs/scholify-roadmap-tracker/requirements.md` (Requirement Q2)
- Design: `.kiro/specs/scholify-roadmap-tracker/design.md` (Section Q2)
