/// An authenticated session returned after the authentication service validates it.
/// A locally stored flag or a guest visit must never create an AppSession.
class AppSession {
  const AppSession({required this.userId, required this.expiresAt});

  final String userId;
  final DateTime expiresAt;

  bool get isValid =>
      userId.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
}

/// Implementations must validate saved credentials with the authentication
/// service, refresh them when appropriate, and return null when signed out.
abstract interface class SessionRepository {
  Future<AppSession?> restoreSession();
  Future<void> signOut();
}

/// No authentication server has been configured for this frontend yet.
/// Existing prayer records are device data, not evidence of authentication.
class UnconfiguredSessionRepository implements SessionRepository {
  const UnconfiguredSessionRepository();

  @override
  Future<AppSession?> restoreSession() async => null;

  @override
  Future<void> signOut() async {}
}
