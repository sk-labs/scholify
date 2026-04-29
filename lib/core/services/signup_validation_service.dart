/// Service for validating self-service tenant signup inputs
/// 
/// Feature: scholify-roadmap-tracker
/// Requirements: B1.2, B1.3, B1.4, B1.8
/// 
/// This service provides validation logic for the Self-Service Signup flow:
/// - School name validation (non-empty after trimming)
/// - Owner full name validation (non-empty after trimming)
/// - Email validation (contains @ and domain)
/// - Password validation (minimum 8 characters)
class SignupValidationService {
  /// Validates school name according to B1.2
  /// 
  /// For any string input as school name, the signup form SHALL accept it if and only if
  /// it is non-empty after trimming whitespace.
  bool validateSchoolName(String schoolName) {
    return schoolName.trim().isNotEmpty;
  }

  /// Validates owner full name
  /// 
  /// For any string input as owner full name, the signup form SHALL accept it if and only if
  /// it is non-empty after trimming whitespace.
  bool validateOwnerFullName(String fullName) {
    return fullName.trim().isNotEmpty;
  }

  /// Validates email format according to B1.3
  /// 
  /// For any string input as email, the signup form SHALL accept it if and only if it contains
  /// at least one @ character followed by at least one character (domain segment)
  bool validateEmail(String email) {
    final atIndex = email.indexOf('@');
    if (atIndex == -1) return false;
    
    // Check if there's at least one character after @
    return atIndex < email.length - 1;
  }

  /// Validates password length according to B1.8
  /// 
  /// Property 13: Signup Password Length Validation
  /// For any string input as password, the signup form SHALL accept it if and only if
  /// its length is at least 8 characters.
  bool validatePassword(String password) {
    return password.length >= 8;
  }

  /// Validates all signup inputs together
  /// 
  /// Returns a map with validation results for each field
  Map<String, bool> validateAll({
    required String schoolName,
    required String ownerFullName,
    required String email,
    required String password,
  }) {
    return {
      'schoolName': validateSchoolName(schoolName),
      'ownerFullName': validateOwnerFullName(ownerFullName),
      'email': validateEmail(email),
      'password': validatePassword(password),
    };
  }
}
