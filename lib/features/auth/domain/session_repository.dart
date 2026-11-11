/// A session returned only after the authentication service verifies the user.
class AppSession {
  const AppSession({required this.userId, required this.expiresAt, this.email});

  final String userId;
  final DateTime expiresAt;
  final String? email;

  bool get isValid =>
      userId.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
}

abstract interface class SessionRepository {
  Future<AppSession?> restoreSession();
  Future<void> signOut();
}

/// Email verification is required before a session can be returned.
abstract interface class EmailAuthRepository implements SessionRepository {
  bool get isConfigured;
  Stream<AppSession?> get sessionChanges;
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  });
  Future<void> resendVerificationEmail({required String email});
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Keeps email forms available without pretending that mail has been sent.
class UnconfiguredSessionRepository implements EmailAuthRepository {
  const UnconfiguredSessionRepository();

  static const _missing = AuthFailure(
    '이메일 인증 서비스가 연결되지 않았어요. 서비스 설정 후 다시 시도해 주세요.',
  );

  @override
  bool get isConfigured => false;
  @override
  Stream<AppSession?> get sessionChanges => const Stream.empty();
  @override
  Future<AppSession?> restoreSession() async => null;
  @override
  Future<void> signOut() async {}
  @override
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async => throw _missing;
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async => throw _missing;
  @override
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  }) async => throw _missing;
  @override
  Future<void> resendVerificationEmail({required String email}) async =>
      throw _missing;
}
