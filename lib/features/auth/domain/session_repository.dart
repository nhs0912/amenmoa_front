import 'package:characters/characters.dart';

/// A session returned only after the authentication service verifies the user.
class AppSession {
  const AppSession({
    required this.userId,
    required this.expiresAt,
    this.email,
    this.nickname,
  });

  final String userId;
  final DateTime expiresAt;
  final String? email;
  final String? nickname;

  bool get hasNickname => validateNickname(nickname) == null;

  bool get isValid =>
      userId.trim().isNotEmpty && expiresAt.isAfter(DateTime.now());
}

/// Nicknames are display data only, never an authorization or identity claim.
/// Count user-visible grapheme clusters so Korean and joined emoji behave alike.
String? validateNickname(String? value) {
  if (value == null || value.trim().isEmpty) return '닉네임을 입력해 주세요.';
  if (RegExp(
    r'[\u0000-\u001F\u007F-\u009F\u200B\u200E\u200F\u202A-\u202E\u2060-\u206F\uFEFF]',
  ).hasMatch(value)) {
    return '닉네임에 줄바꿈이나 숨겨진 제어 문자를 넣을 수 없어요.';
  }
  final length = value.trim().characters.length;
  if (length < 2 || length > 20) return '닉네임은 2자 이상 20자 이하로 입력해 주세요.';
  return null;
}

abstract interface class NicknameRepository {
  Future<AppSession> saveNickname(String nickname);
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

/// Some projects send a confirmation link; custom SMTP can instead send a code.
enum EmailVerificationMethod { code, link }

abstract interface class EmailVerificationPolicy {
  EmailVerificationMethod get emailVerificationMethod;
}

extension EmailAuthVerificationPolicy on EmailAuthRepository {
  EmailVerificationMethod get verificationMethod =>
      this is EmailVerificationPolicy
      ? (this as EmailVerificationPolicy).emailVerificationMethod
      : EmailVerificationMethod.code;
}
