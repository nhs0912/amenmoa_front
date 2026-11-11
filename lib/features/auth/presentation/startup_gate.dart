import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/app_shell.dart';
import '../../../app/theme/app_theme.dart';
import '../domain/session_repository.dart';
import 'brand_logo.dart';
import 'email_auth_pages.dart';

class StartupGate extends StatefulWidget {
  const StartupGate({
    super.key,
    this.sessionRepository = const UnconfiguredSessionRepository(),
    this.minimumSplashDuration = const Duration(milliseconds: 1600),
  });

  final SessionRepository sessionRepository;
  final Duration minimumSplashDuration;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> with WidgetsBindingObserver {
  bool _loading = true;
  bool _guest = false;
  bool _signingOut = false;
  bool _refreshing = false;
  int _sessionVersion = 0;
  AppSession? _session;
  String? _error;
  Timer? _expiryTimer;
  StreamSubscription<AppSession?>? _sessionSubscription;

  EmailAuthRepository get _emailAuth =>
      widget.sessionRepository is EmailAuthRepository
      ? widget.sessionRepository as EmailAuthRepository
      : const UnconfiguredSessionRepository();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionSubscription = _emailAuth.sessionChanges.listen(
      (session) {
        // Signing in and verifying email open the home only after their request
        // completes successfully. Later events renew or invalidate that session.
        if (!mounted || _loading || _signingOut || _session == null) return;
        if (session == null) {
          _showSignedOut('로그인이 해제됐어요. 다시 로그인해 주세요.');
        } else if (session.isValid) {
          setState(() => _session = session);
          _scheduleSessionCheck();
        }
      },
      onError: (Object _) {
        // A temporary network failure must not erase persistent credentials.
      },
    );
    unawaited(_restore());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    unawaited(_sessionSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loading && _session != null) {
      unawaited(_refreshSession());
    }
  }

  Future<void> _restore() async {
    _expiryTimer?.cancel();
    if (!_loading) setState(() => _loading = true);
    final minimumDisplay = Future<void>.delayed(widget.minimumSplashDuration);
    AppSession? session;
    String? error;
    try {
      session = await widget.sessionRepository.restoreSession().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      error = '로그인 상태를 확인하지 못했어요. 다시 시도해 주세요.';
    }
    await minimumDisplay;
    if (!mounted) return;
    setState(() {
      _session = session != null && session.isValid ? session : null;
      _guest = false;
      _loading = false;
      _error = error;
    });
    _scheduleSessionCheck();
  }

  void _scheduleSessionCheck() {
    _expiryTimer?.cancel();
    if (_session == null) return;
    final remaining = _session!.expiresAt.difference(DateTime.now());
    _expiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => unawaited(_refreshSession()),
    );
  }

  Future<void> _refreshSession() async {
    if (_refreshing || _signingOut || _session == null) return;
    _refreshing = true;
    final version = _sessionVersion;
    try {
      final session = await widget.sessionRepository.restoreSession().timeout(
        const Duration(seconds: 10),
      );
      if (!mounted || version != _sessionVersion || _signingOut) return;
      if (session == null || !session.isValid) {
        _showSignedOut('로그인 시간이 만료됐어요. 다시 로그인해 주세요.');
      } else {
        setState(() => _session = session);
        _scheduleSessionCheck();
      }
    } catch (_) {
      if (mounted && version == _sessionVersion && _session != null) {
        // Let the service retry its refresh after reconnecting. No password is
        // needed and the stored refresh credential is kept on network errors.
        _expiryTimer?.cancel();
        _expiryTimer = Timer(
          const Duration(seconds: 30),
          () => unawaited(_refreshSession()),
        );
      }
    } finally {
      _refreshing = false;
    }
  }

  void _showSignedOut(String? error) {
    _sessionVersion++;
    _expiryTimer?.cancel();
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = null;
      _guest = false;
      _error = error;
    });
  }

  void _completeSignIn(AppSession session) {
    if (!mounted || !session.isValid) return;
    _sessionVersion++;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _session = session;
      _guest = false;
      _error = null;
    });
    _scheduleSessionCheck();
  }

  Future<void> _exitToLogin() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    _sessionVersion++;
    try {
      if (_session != null) await widget.sessionRepository.signOut();
      if (!mounted) return;
      _showSignedOut(null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  void _openEmailPage({required bool signUp}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => signUp
            ? EmailSignUpPage(
                repository: _emailAuth,
                onAuthenticated: _completeSignIn,
              )
            : EmailLoginPage(
                repository: _emailAuth,
                onAuthenticated: _completeSignIn,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const StartupSplash();
    if (_session != null || _guest) {
      return AppShell(
        key: ValueKey(_session?.userId ?? 'guest'),
        userId: _session?.userId,
        accountEmail: _session?.email,
        signingOut: _signingOut,
        onExitToLogin: _exitToLogin,
      );
    }
    return LoginScreen(
      error: _error,
      onRetry: _restore,
      onBrowse: () => setState(() => _guest = true),
      onEmailLogin: () => _openEmailPage(signUp: false),
      onEmailSignUp: () => _openEmailPage(signUp: true),
    );
  }
}

class StartupSplash extends StatelessWidget {
  const StartupSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('startup-splash'),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const BrandLogo(size: 112),
                  SizedBox(height: 24),
                  Text(
                    '아멘모아',
                    style: TextStyle(
                      color: AppTheme.seedColor,
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    '각자의 자리에서,\n같은 마음으로.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6C7E74),
                      fontSize: 17,
                      height: 1.7,
                    ),
                  ),
                  SizedBox(height: 40),
                  Semantics(
                    label: '아멘모아 시작 중',
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.onBrowse,
    required this.onRetry,
    required this.onEmailLogin,
    required this.onEmailSignUp,
    this.error,
  });

  final VoidCallback onBrowse;
  final VoidCallback onRetry;
  final VoidCallback onEmailLogin;
  final VoidCallback onEmailSignUp;
  final String? error;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const ValueKey('login-screen'),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(size: 64),
              ),
              const SizedBox(height: 28),
              const Text(
                '아멘모아 시작하기',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.seedColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '각자의 자리에서, 같은 마음으로.\n함께하는 기도의 첫걸음을 시작해요.',
                style: TextStyle(color: Color(0xFF6C7E74), height: 1.7),
              ),
              const SizedBox(height: 28),
              if (error != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    error!,
                    style: const TextStyle(color: Color(0xFF9B342F)),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onRetry,
                    child: const Text('다시 확인'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                '이메일로 가입하거나 로그인해 주세요.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '한 번 로그인하면 다음에도 편하게 이어갈 수 있어요.',
                style: TextStyle(color: Color(0xFF6C7E74), height: 1.6),
              ),
              const SizedBox(height: 20),
              const _LoginOption(
                label: '카카오톡으로 계속하기',
                icon: Icons.chat_bubble_outline,
              ),
              const SizedBox(height: 10),
              const _LoginOption(
                label: 'Google로 계속하기',
                icon: Icons.account_circle_outlined,
              ),
              const SizedBox(height: 10),
              const _LoginOption(label: 'Apple로 계속하기', icon: Icons.apple),
              const SizedBox(height: 10),
              _LoginOption(
                label: '이메일로 로그인',
                icon: Icons.mail_outline,
                onPressed: onEmailLogin,
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onEmailSignUp,
                child: const Text('이메일로 가입'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(),
              ),
              FilledButton(
                onPressed: onBrowse,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Text('기기 저장 모드로 둘러보기'),
              ),
              const SizedBox(height: 14),
              const Text(
                '기기 저장 모드는 로그인되지 않아요.\n앱을 다시 열면 이 화면에서 시작해요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6C7E74),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoginOption extends StatelessWidget {
  const _LoginOption({required this.label, required this.icon, this.onPressed});

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 20),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(double.infinity, 52),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
