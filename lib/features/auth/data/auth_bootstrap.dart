import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/session_repository.dart';
import 'secure_session_storage.dart';
import 'supabase_email_auth_repository.dart';

/// Public, app-side configuration only. Never pass a Supabase secret/service key.
Future<SessionRepository> createSessionRepository() async {
  const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://hgytwbzapltumfdyqkkw.supabase.co',
  );
  const publishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const verificationMethod = String.fromEnvironment(
    'EMAIL_VERIFICATION_METHOD',
    defaultValue: 'link',
  );
  const legacyAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  // This is a public frontend key, not a Supabase secret/service-role key.
  const defaultPublishableKey =
      'sb_publishable_q4kFMuw9r85zqWCp09UdfA_j15TLKeQ';
  final key = publishableKey.isNotEmpty
      ? publishableKey
      : legacyAnonKey.isNotEmpty
      ? legacyAnonKey
      : defaultPublishableKey;
  if (url.isEmpty || key.isEmpty) return const UnconfiguredSessionRepository();
  final uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !_isPublicKey(key)) {
    return const _UnavailableAuthRepository('이메일 인증 서비스의 공개 연결 설정을 확인해 주세요.');
  }
  try {
    final storage = SecureSessionStorage(
      storageKey: 'amenmoa.auth.${uri.host}',
    );
    final supabase = await Supabase.initialize(
      url: url,
      publishableKey: key,
      debug: false,
      authOptions: FlutterAuthClientOptions(
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUri: false,
        localStorage: storage,
      ),
    );
    return SupabaseEmailAuthRepository(
      client: supabase.client,
      storage: storage,
      emailVerificationMethod: verificationMethod == 'code'
          ? EmailVerificationMethod.code
          : EmailVerificationMethod.link,
    );
  } catch (_) {
    return const _UnavailableAuthRepository(
      '안전한 로그인 저장소를 열지 못했어요. 앱을 다시 실행해 주세요.',
    );
  }
}

bool _isPublicKey(String key) {
  if (key.startsWith('sb_publishable_')) return true;
  if (key.startsWith('sb_secret_')) return false;
  // Legacy anon keys are JWTs. Reject service-role JWTs before initialization.
  try {
    final parts = key.split('.');
    if (parts.length != 3) return false;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    ) as Map<String, dynamic>;
    return claims['role'] == 'anon';
  } catch (_) {
    return false;
  }
}

class _UnavailableAuthRepository extends UnconfiguredSessionRepository {
  const _UnavailableAuthRepository(this.message);
  final String message;
  @override
  Future<AppSession?> restoreSession() async => throw AuthFailure(message);
  @override
  Future<AppSession> signInWithEmail({
    required String email,
    required String password,
  }) async => throw AuthFailure(message);
  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async => throw AuthFailure(message);
  @override
  Future<AppSession> verifyEmail({
    required String email,
    required String token,
  }) async => throw AuthFailure(message);
  @override
  Future<void> resendVerificationEmail({required String email}) async =>
      throw AuthFailure(message);
}
