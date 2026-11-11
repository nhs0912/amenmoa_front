import 'dart:convert';

import 'package:amenmoa_front/features/auth/data/secure_session_storage.dart';
import 'package:amenmoa_front/features/auth/data/supabase_email_auth_repository.dart';
import 'package:amenmoa_front/features/auth/domain/session_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testEmail = 'seoyun@example.com';
const testPassword = 'Peaceful2026!';
const testUserId = 'verified-user-id';
const storageKey = 'test.auth.session';

Map<String, dynamic> userJson({bool confirmed = true}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    'id': testUserId,
    'aud': 'authenticated',
    'role': 'authenticated',
    'email': testEmail,
    'email_confirmed_at': confirmed ? now : null,
    'created_at': now,
    'updated_at': now,
    'app_metadata': {
      'provider': 'email',
      'providers': ['email'],
    },
    'user_metadata': <String, dynamic>{},
    'identities': <Object>[],
  };
}

Map<String, dynamic> sessionJson({bool confirmed = true}) {
  String encodePart(Map<String, dynamic> value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  final expiry =
      DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/
      1000;
  final access =
      '${encodePart({'alg': 'HS256', 'typ': 'JWT'})}.${encodePart({'sub': testUserId, 'aud': 'authenticated', 'exp': expiry})}.test-signature';
  return {
    'access_token': access,
    'refresh_token': 'test-refresh-credential',
    'token_type': 'bearer',
    'expires_in': 3600,
    'user': userJson(confirmed: confirmed),
  };
}

http.Response response(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);

class MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

class AuthFixture {
  AuthFixture() {
    httpClient = MockClient((request) => route(request));
    client = SupabaseClient(
      'https://project.supabase.co',
      'sb_publishable_test',
      httpClient: httpClient,
      authOptions: AuthClientOptions(
        autoRefreshToken: false,
        pkceAsyncStorage: MemoryPkceStorage(),
      ),
    );
    storage = SecureSessionStorage(storageKey: storageKey);
    repository = SupabaseEmailAuthRepository(client: client, storage: storage);
  }

  late final MockClient httpClient;
  late final SupabaseClient client;
  late final SecureSessionStorage storage;
  late final SupabaseEmailAuthRepository repository;
  Future<http.Response> Function(http.Request) route = (request) async {
    if (request.url.path.endsWith('/token')) return response(sessionJson());
    if (request.url.path.endsWith('/user')) return response(userJson());
    if (request.url.path.endsWith('/logout')) return response({});
    throw StateError(
      'Unexpected test request: ${request.method} ${request.url.path}',
    );
  };

  Future<AppSession> signIn() =>
      repository.signInWithEmail(email: testEmail, password: testPassword);

  Future<void> dispose() async {
    await client.dispose();
    httpClient.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('signup stays signed out until verified email session is securely persisted', () async {
    final fixture = AuthFixture();
    addTearDown(fixture.dispose);
    fixture.route = (request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (request.url.path.endsWith('/signup')) {
        expect(body['email'], testEmail);
        return response(userJson(confirmed: false));
      }
      if (request.url.path.endsWith('/verify')) {
        expect(body['email'], testEmail);
        expect(body['token'], '654321');
        expect(body['type'], 'email');
        return response(sessionJson());
      }
      throw StateError('Unexpected test request: ${request.url.path}');
    };

    await fixture.repository.signUpWithEmail(
      email: testEmail,
      password: testPassword,
    );
    expect(fixture.client.auth.currentSession, isNull);
    expect(await fixture.storage.accessToken(), isNull);

    final session = await fixture.repository.verifyEmail(
      email: testEmail,
      token: '654321',
    );
    expect(session.userId, testUserId);
    expect(session.email, testEmail);
    expect(session.isValid, isTrue);
    final saved = (await fixture.storage.accessToken())!;
    final persisted = jsonDecode(saved) as Map<String, dynamic>;
    expect(persisted['refresh_token'], 'test-refresh-credential');
    expect((persisted['user'] as Map)['email_confirmed_at'], isNotNull);
    expect(saved, isNot(contains(testPassword)));
    expect(saved, isNot(contains('654321')));
  });

  test(
    'unverified login and auto-confirm signup cannot bypass email verification',
    () async {
      final fixture = AuthFixture();
      addTearDown(fixture.dispose);
      fixture.route = (request) async {
        if (request.url.path.endsWith('/token')) {
          return response(sessionJson(confirmed: false));
        }
        if (request.url.path.endsWith('/signup')) {
          return response(sessionJson());
        }
        if (request.url.path.endsWith('/logout')) return response({});
        throw StateError('Unexpected test request: ${request.url.path}');
      };

      await expectLater(fixture.signIn(), throwsA(isA<AuthFailure>()));
      expect(fixture.client.auth.currentSession, isNull);
      expect(await fixture.storage.accessToken(), isNull);
      await expectLater(
        fixture.repository.signUpWithEmail(
          email: testEmail,
          password: testPassword,
        ),
        throwsA(isA<AuthFailure>()),
      );
      expect(fixture.client.auth.currentSession, isNull);
      expect(await fixture.storage.accessToken(), isNull);
    },
  );

  test(
    'restore preserves credentials offline but removes a rejected session',
    () async {
      final fixture = AuthFixture();
      addTearDown(fixture.dispose);
      await fixture.signIn();
      final saved = await fixture.storage.accessToken();
      bool offline = true;
      fixture.route = (request) async {
        if (request.url.path.endsWith('/user')) {
          if (offline) throw http.ClientException('test network unavailable');
          return response({'code': 'bad_jwt', 'msg': 'Invalid token'}, 401);
        }
        if (request.url.path.endsWith('/logout')) return response({});
        throw StateError('Unexpected test request: ${request.url.path}');
      };

      await expectLater(
        fixture.repository.restoreSession(),
        throwsA(isA<AuthFailure>()),
      );
      expect(await fixture.storage.accessToken(), saved);
      expect(fixture.client.auth.currentSession, isNotNull);

      offline = false;
      expect(await fixture.repository.restoreSession(), isNull);
      expect(await fixture.storage.accessToken(), isNull);
      expect(fixture.client.auth.currentSession, isNull);
    },
  );

  test(
    'saved credentials restore only after the server verifies the user',
    () async {
      final first = AuthFixture();
      await first.signIn();
      final saved = (await first.storage.accessToken())!;
      await first.dispose();

      final restarted = AuthFixture();
      addTearDown(restarted.dispose);
      int userChecks = 0;
      restarted.route = (request) async {
        if (request.url.path.endsWith('/user')) {
          userChecks++;
          return response(userJson());
        }
        throw StateError('Unexpected test request: ${request.url.path}');
      };
      await restarted.client.auth.recoverSession(saved);
      final session = await restarted.repository.restoreSession();
      expect(userChecks, 1);
      expect(session?.userId, testUserId);
      expect(session?.isValid, isTrue);
      expect(await restarted.storage.accessToken(), isNotNull);
    },
  );

  test(
    'offline logout clears memory and storage and ignores queued late writes',
    () async {
      final fixture = AuthFixture();
      addTearDown(fixture.dispose);
      await fixture.signIn();
      final saved = (await fixture.storage.accessToken())!;
      fixture.route = (request) async {
        expect(request.url.path.endsWith('/logout'), isTrue);
        throw http.ClientException('test network unavailable');
      };

      final queuedWrite = fixture.storage.persistSession(saved);
      final logout = fixture.repository.signOut();
      await Future.wait([queuedWrite, logout]);
      await fixture.storage.persistSession(saved);
      expect(fixture.client.auth.currentSession, isNull);
      expect(await fixture.storage.accessToken(), isNull);
      expect(await fixture.repository.restoreSession(), isNull);
    },
  );
}
