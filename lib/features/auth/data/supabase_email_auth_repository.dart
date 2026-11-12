import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/session_repository.dart';
import 'secure_session_storage.dart';

class SupabaseEmailAuthRepository
    implements EmailAuthRepository, EmailVerificationPolicy {
  SupabaseEmailAuthRepository({
    required this.client,
    required this.storage,
    this.emailVerificationMethod = EmailVerificationMethod.code,
  });

  final SupabaseClient client;
  final SecureSessionStorage storage;
  @override
  final EmailVerificationMethod emailVerificationMethod;
  bool _allowSessionEvents = false;
  static const _requestTimeout = Duration(seconds: 10);

  @override
  bool get isConfigured => true;

  @override
  Stream<AppSession?> get sessionChanges => client.auth.onAuthStateChange
      .where(
        (state) =>
            state.event == AuthChangeEvent.signedOut ||
            (_allowSessionEvents &&
                state.session != null &&
                _isVerified(state.session!.user)),
      )
      .asyncMap((state) async {
        if (state.event == AuthChangeEvent.signedOut) {
          _allowSessionEvents = false;
          return null;
        }
        final session = state.session;
        if (session == null || !_isVerified(session.user)) return null;
        await storage.persistSession(jsonEncode(session.toJson()));
        return _toAppSession(session, session.user);
      })
      .transform(
        StreamTransformer<AppSession?, AppSession?>.fromHandlers(
          handleError: (error, stack, sink) =>
              sink.addError(_failureFor(error), stack),
        ),
      );

  @override
  Future<AppSession?> restoreSession() async {
    try {
      var session = client.auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) {
        session = (await client.auth.refreshSession().timeout(_requestTimeout))
            .session;
      }
      if (session == null) return null;
      // A local JWT alone cannot establish a trusted authenticated user.
      final response = await client.auth.getUser().timeout(_requestTimeout);
      final user = response.user;
      if (user == null || !_isVerified(user) || user.id != session.user.id) {
        await _clearLocalSession();
        return null;
      }
      return await _acceptSession(session, user);
    } on AuthException catch (error) {
      if (_isInvalidSession(error)) {
        await _clearLocalSession();
        return null;
      }
      // Keep the refresh token on transient failures so Retry can restore it.
      throw _failureFor(error);
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw _failureFor(error);
    }
  }

  @override
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await client.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(_requestTimeout);
      return await _validateAndAccept(response);
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw _failureFor(error);
    }
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _allowSessionEvents = false;
    storage.suspendWrites();
    try {
      final response = await client.auth
          .signUp(email: email.trim(), password: password)
          .timeout(_requestTimeout);
      if (response.session != null) {
        // The app's signup contract requires email confirmation on the server.
        // A misconfigured auto-confirm project must not skip verification.
        await _clearLocalSession();
        throw const AuthFailure('이메일 인증을 필수로 하는 서비스 설정이 필요해요. 관리자에게 문의해 주세요.');
      }
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw _failureFor(error);
    }
  }

  @override
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  }) async {
    try {
      final response = await client.auth
          .verifyOTP(
            email: email.trim(),
            token: token.trim(),
            type: OtpType.email,
          )
          .timeout(_requestTimeout);
      return await _validateAndAccept(response);
    } catch (error) {
      if (error is AuthFailure) rethrow;
      throw _failureFor(error);
    }
  }

  @override
  Future<void> resendVerificationEmail({required String email}) async {
    try {
      await client.auth
          .resend(type: OtpType.signup, email: email.trim())
          .timeout(_requestTimeout);
    } catch (error) {
      throw _failureFor(error);
    }
  }

  Future<AppSession> _validateAndAccept(AuthResponse response) async {
    final session = response.session;
    final user = response.user;
    if (session == null || user == null || !_isVerified(user)) {
      await _clearLocalSession();
      throw const AuthFailure('이메일 인증을 마친 뒤 로그인해 주세요.');
    }
    return _acceptSession(session, user);
  }

  Future<AppSession> _acceptSession(Session session, User user) async {
    final result = _toAppSession(session, user);
    if (!result.isValid) {
      throw const AuthFailure('로그인 시간이 만료됐어요. 다시 로그인해 주세요.');
    }
    storage.resumeWrites();
    try {
      // Explicitly await persistence: the SDK's auth-event persistence is async.
      await storage.persistSession(jsonEncode(session.toJson()));
    } catch (_) {
      await _clearLocalSession();
      throw const AuthFailure('로그인 정보를 안전하게 저장하지 못했어요. 다시 시도해 주세요.');
    }
    _allowSessionEvents = true;
    return result;
  }

  @override
  Future<void> signOut() => _clearLocalSession();

  Future<void> _clearLocalSession() async {
    _allowSessionEvents = false;
    storage.suspendWrites();
    try {
      // GoTrue removes the in-memory session before requesting revocation.
      await client.auth
          .signOut(scope: SignOutScope.local)
          .timeout(_requestTimeout);
    } catch (_) {
      // Logging out of this device must also work while the network is offline.
      // The SDK clears memory before the request; durable storage is cleared below.
    }
    try {
      await storage.removePersistedSession();
    } catch (_) {
      throw const AuthFailure('기기의 로그인 정보를 지우지 못했어요. 다시 시도해 주세요.');
    }
  }

  static bool _isVerified(User user) =>
      user.email?.isNotEmpty == true && user.emailConfirmedAt != null;

  static AppSession _toAppSession(Session session, User user) => AppSession(
    userId: user.id,
    expiresAt: DateTime.fromMillisecondsSinceEpoch(
      (session.expiresAt ?? 0) * 1000,
    ),
    email: user.email,
  );

  static bool _isInvalidSession(AuthException error) =>
      error is AuthSessionMissingException ||
      error is AuthInvalidJwtException ||
      error.statusCode == '401' ||
      error.statusCode == '403' ||
      const {
        'refresh_token_not_found',
        'refresh_token_already_used',
        'session_not_found',
        'session_expired',
        'user_not_found',
        'user_banned',
        'invalid_jwt',
        'bad_jwt',
      }.contains(error.code);

  static AuthFailure _failureFor(Object error) {
    if (error is AuthFailure) return error;
    if (error is TimeoutException || error is AuthRetryableFetchException) {
      return const AuthFailure('연결이 원활하지 않아요. 네트워크를 확인한 뒤 다시 시도해 주세요.');
    }
    if (error is AuthException) {
      switch (error.code) {
        case 'invalid_credentials':
          return const AuthFailure('이메일 또는 비밀번호가 올바르지 않아요.');
        case 'email_not_confirmed':
          return const AuthFailure('이메일 인증을 먼저 완료해 주세요.');
        case 'email_exists':
        case 'user_already_exists':
          return const AuthFailure(
            '이미 가입했거나 사용할 수 없는 이메일이에요. 로그인하거나 다른 주소를 사용해 주세요.',
          );
        case 'otp_expired':
        case 'otp_disabled':
        case 'otp_not_found':
          return const AuthFailure('인증코드가 올바르지 않거나 만료됐어요. 새 코드를 받아 주세요.');
        case 'weak_password':
          return const AuthFailure('비밀번호가 보안 기준에 맞지 않아요. 더 긴 비밀번호를 사용해 주세요.');
        case 'email_address_invalid':
        case 'validation_failed':
          return const AuthFailure('이메일 주소와 입력 내용을 확인해 주세요.');
        case 'over_email_send_rate_limit':
        case 'over_request_rate_limit':
        case 'over_request_retry_limit':
          return const AuthFailure('요청이 많아요. 잠시 기다린 뒤 다시 시도해 주세요.');
        case 'email_address_not_authorized':
          return const AuthFailure(
            '이 주소로 인증 메일을 보낼 수 없어요. 서비스의 이메일 발송 설정을 확인해 주세요.',
          );
        case 'signup_disabled':
          return const AuthFailure('현재 가입을 받을 수 없어요. 잠시 후 다시 시도해 주세요.');
        case 'captcha_failed':
          return const AuthFailure('보안 확인 설정을 확인해야 해요. 관리자에게 문의해 주세요.');
      }
      if (error.statusCode == '429') {
        return const AuthFailure('요청이 많아요. 잠시 기다린 뒤 다시 시도해 주세요.');
      }
      if (int.tryParse(error.statusCode ?? '') case final status?
          when status >= 500) {
        return const AuthFailure('인증 서비스에 잠시 연결할 수 없어요. 다시 시도해 주세요.');
      }
    }
    return const AuthFailure('요청을 완료하지 못했어요. 연결을 확인하고 다시 시도해 주세요.');
  }
}
