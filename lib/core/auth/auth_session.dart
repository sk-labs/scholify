class AuthSession {
  const AuthSession({
    required this.userId,
    required this.email,
    required this.tenantId,
    required this.tenantName,
    required this.role,
    required this.isSuperAdmin,
  });

  final String userId;
  final String email;
  final String tenantId;
  final String tenantName;
  final String role;
  final bool isSuperAdmin;
}
