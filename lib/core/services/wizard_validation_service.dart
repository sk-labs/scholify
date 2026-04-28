import 'package:scholify/core/database/local_database.dart';

/// Service for validating tenant onboarding wizard inputs
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: H1.2, H1.3, H1.4
/// 
/// This service provides validation logic for the Tenant Onboarding Wizard:
/// - School name validation (non-empty after trimming)
/// - Tenant ID derivation (lowercase, replace non-alphanumeric with underscore)
/// - Plan validation (starter, professional, enterprise)
/// - Seat limit validation (positive integer)
/// - Email validation (contains @ and domain)
class WizardValidationService {
  final AppLocalDatabase database;

  WizardValidationService({required this.database});

  /// Validates school name according to H1.2
  /// 
  /// For any string input as school name, the wizard SHALL accept it if and only if
  /// it is non-empty after trimming whitespace.
  bool validateSchoolName(String schoolName) {
    return schoolName.trim().isNotEmpty;
  }

  /// Derives tenant_id from school name
  /// 
  /// Converts to lowercase and replaces non-alphanumeric characters with underscore
  String deriveTenantId(String schoolName) {
    return schoolName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_');
  }

  /// Checks if a tenant_id already exists in the database
  Future<bool> tenantIdExists(String tenantId) async {
    final query = database.select(database.tenantRecords)
      ..where((t) => t.id.equals(tenantId));
    
    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Validates plan code according to H1.3
  /// 
  /// For any plan code, the wizard SHALL accept it if and only if the plan is one of
  /// starter, professional, or enterprise (case-insensitive)
  bool validatePlan(String planCode) {
    final normalized = planCode.toLowerCase().trim();
    return normalized == 'starter' || 
           normalized == 'professional' || 
           normalized == 'enterprise';
  }

  /// Validates seat limit according to H1.3
  /// 
  /// For any seat limit, the wizard SHALL accept it if and only if it is a positive integer
  bool validateSeatLimit(int seatLimit) {
    return seatLimit > 0;
  }

  /// Validates email format according to H1.4
  /// 
  /// For any string input as email, the wizard SHALL accept it if and only if it contains
  /// at least one @ character followed by at least one character (domain segment)
  bool validateEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return false;
    
    // Check if there's at least one character after @
    return atIndex < email.length - 1;
  }

  /// Validates all wizard inputs together
  /// 
  /// Returns a map with validation results for each field
  Map<String, bool> validateAll({
    required String schoolName,
    required String planCode,
    required int seatLimit,
    required String email,
  }) {
    return {
      'schoolName': validateSchoolName(schoolName),
      'plan': validatePlan(planCode),
      'seatLimit': validateSeatLimit(seatLimit),
      'email': validateEmail(email),
    };
  }
}
