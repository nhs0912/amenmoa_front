import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/session_repository.dart';
import 'brand_logo.dart';

const _muted = Color(0xFF6C7E74);

String? _validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return '이메일 주소를 입력해 주세요.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return '이메일 주소를 확인해 주세요.';
  }
  return null;
}

String _errorMessage(Object error) => error is AuthFailure
    ? error.message
    : '요청을 완료하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';

class EmailLoginPage extends StatefulWidget {
  const EmailLoginPage({
    super.key,
    required this.repository,
    required this.onAuthenticated,
  });

  final EmailAuthRepository repository;
  final ValueChanged<AppSession> onAuthenticated;

  @override
  State<EmailLoginPage> createState() => _EmailLoginPageState();
}

class _EmailLoginPageState extends State<EmailLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await widget.repository.signInWithEmail(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      _password.clear();
      TextInput.finishAutofillContext();
      widget.onAuthenticated(session);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: '이메일로 로그인',
    subtitle: '가입한 이메일과 비밀번호를 입력해 주세요.',
    child: Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConfigurationNotice(configured: widget.repository.isConfigured),
            TextFormField(
              key: const ValueKey('email-login-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.username,
                AutofillHints.email,
              ],
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: '이메일'),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('email-login-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixIcon: IconButton(
                  tooltip: _obscure ? '비밀번호 표시' : '비밀번호 숨기기',
                  onPressed: _busy
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? '비밀번호를 입력해 주세요.' : null,
            ),
            const SizedBox(height: 14),
            const Text(
              '로그인하면 다음에도 자동으로 로그인돼요.',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            _ErrorNotice(message: _error),
            const SizedBox(height: 24),
            _SubmitButton(
              buttonKey: const ValueKey('email-login-submit'),
              label: '로그인',
              busyLabel: '로그인 중',
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => EmailSignUpPage(
                          repository: widget.repository,
                          onAuthenticated: widget.onAuthenticated,
                          initialEmail: _email.text.trim(),
                        ),
                      ),
                    ),
              child: const Text('처음이신가요? 이메일로 가입'),
            ),
          ],
        ),
      ),
    ),
  );
}

class EmailSignUpPage extends StatefulWidget {
  const EmailSignUpPage({
    super.key,
    required this.repository,
    required this.onAuthenticated,
    this.initialEmail = '',
  });

  final EmailAuthRepository repository;
  final ValueChanged<AppSession> onAuthenticated;
  final String initialEmail;

  @override
  State<EmailSignUpPage> createState() => _EmailSignUpPageState();
}

class _EmailSignUpPageState extends State<EmailSignUpPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.signUpWithEmail(email: email, password: password);
      if (!mounted) return;
      _password.clear();
      _confirmation.clear();
      TextInput.finishAutofillContext(shouldSave: false);
      unawaited(
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => EmailVerificationPage(
              repository: widget.repository,
              email: email,
              pendingPassword:
                  widget.repository.verificationMethod ==
                      EmailVerificationMethod.link
                  ? password
                  : null,
              onAuthenticated: widget.onAuthenticated,
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: '이메일로 가입',
    subtitle: '이메일을 인증한 뒤 아멘모아를 시작할 수 있어요.',
    child: Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ConfigurationNotice(configured: widget.repository.isConfigured),
            TextFormField(
              key: const ValueKey('email-signup-email'),
              controller: _email,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.newUsername,
                AutofillHints.email,
              ],
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: '이메일 주소'),
              validator: _validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('email-signup-password'),
              controller: _password,
              enabled: !_busy,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: '비밀번호',
                helperText: '8자 이상 입력해 주세요.',
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return '비밀번호를 입력해 주세요.';
                if (value.length < 8) return '비밀번호는 8자 이상 입력해 주세요.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('email-signup-confirm-password'),
              controller: _confirmation,
              enabled: !_busy,
              obscureText: _obscureConfirmation,
              autofillHints: const [AutofillHints.newPassword],
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => unawaited(_submit()),
              decoration: InputDecoration(
                labelText: '비밀번호 확인',
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmation ? '비밀번호 확인 표시' : '비밀번호 확인 숨기기',
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _obscureConfirmation = !_obscureConfirmation,
                        ),
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '비밀번호를 한 번 더 입력해 주세요.';
                }
                if (value != _password.text) return '비밀번호가 일치하지 않아요.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(
              widget.repository.verificationMethod ==
                      EmailVerificationMethod.link
                  ? '입력한 주소로 인증 메일을 보내요.\n메일의 인증 링크를 눌러 가입을 완료해 주세요.'
                  : '입력한 주소로 인증 메일을 보내요.\n메일에 적힌 인증번호를 다음 화면에서 입력해 주세요.',
              style: TextStyle(color: _muted, height: 1.6),
            ),
            _ErrorNotice(message: _error),
            const SizedBox(height: 24),
            _SubmitButton(
              buttonKey: const ValueKey('email-signup-submit'),
              label: '인증 메일 보내기',
              busyLabel: '인증 메일 보내는 중',
              busy: _busy,
              onPressed: _submit,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => EmailLoginPage(
                          repository: widget.repository,
                          onAuthenticated: widget.onAuthenticated,
                        ),
                      ),
                    ),
              child: const Text('이미 계정이 있나요? 이메일로 로그인'),
            ),
          ],
        ),
      ),
    ),
  );
}

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.repository,
    required this.email,
    required this.onAuthenticated,
    this.pendingPassword,
  });

  final EmailAuthRepository repository;
  final String email;
  final String? pendingPassword;
  final ValueChanged<AppSession> onAuthenticated;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _formKey = GlobalKey<FormState>();
  final _token = TextEditingController();
  Timer? _cooldown;
  int _remaining = 60;
  bool _busy = false;
  bool _resending = false;
  String? _error;
  String? _notice;
  String? _pendingPassword;

  bool get _usesLink =>
      widget.repository.verificationMethod == EmailVerificationMethod.link;

  @override
  void initState() {
    super.initState();
    _pendingPassword = widget.pendingPassword;
    _startCooldown();
  }

  @override
  void dispose() {
    _cooldown?.cancel();
    _pendingPassword = null;
    _token.dispose();
    super.dispose();
  }

  void _startCooldown() {
    _cooldown?.cancel();
    _remaining = 60;
    _cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    if (_busy || _resending) return;
    if (_usesLink && _pendingPassword == null) {
      _openEmailLogin();
      return;
    }
    if (!_usesLink && !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final session = _usesLink
          ? await widget.repository.signInWithEmail(
              email: widget.email,
              password: _pendingPassword!,
            )
          : await widget.repository.verifyEmail(
              email: widget.email,
              token: _token.text.trim(),
            );
      if (!mounted) return;
      _cooldown?.cancel();
      _token.clear();
      _pendingPassword = null;
      widget.onAuthenticated(session);
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_remaining > 0 || _busy || _resending) return;
    setState(() {
      _resending = true;
      _error = null;
      _notice = null;
    });
    try {
      await widget.repository.resendVerificationEmail(email: widget.email);
      if (!mounted) return;
      setState(() {
        _notice = _usesLink
            ? '인증 메일을 다시 보냈어요. 최근 메일의 인증 링크를 눌러 주세요.'
            : '인증 메일을 다시 보냈어요. 최근 메일의 인증번호를 입력해 주세요.';
        _startCooldown();
      });
    } catch (error) {
      if (mounted) setState(() => _error = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _openEmailLogin() {
    _pendingPassword = null;
    unawaited(
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => EmailLoginPage(
            repository: widget.repository,
            onAuthenticated: widget.onAuthenticated,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: '이메일 인증',
    subtitle: _usesLink ? '메일의 인증 링크를 눌러 주세요.' : '메일을 확인하고 인증번호를 입력해 주세요.',
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ConfigurationNotice(configured: widget.repository.isConfigured),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEDC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 30),
                const SizedBox(height: 14),
                const Text(
                  '인증 메일을 보냈어요',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  widget.email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_usesLink)
            const Text(
              '메일의 인증 링크를 누른 후 이 화면으로 돌아와 주세요.',
              style: TextStyle(
                color: AppTheme.seedColor,
                fontWeight: FontWeight.w600,
                height: 1.7,
              ),
            )
          else
            TextFormField(
              key: const ValueKey('email-verification-token'),
              controller: _token,
              enabled: !_busy && !_resending,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 8,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: '8자리 인증번호',
                hintText: '메일에 적힌 숫자 8자리',
                counterText: '',
              ),
              validator: (value) => RegExp(r'^\d{8}$').hasMatch(value ?? '')
                  ? null
                  : '인증번호 8자리를 입력해 주세요.',
              onFieldSubmitted: (_) => unawaited(_verify()),
            ),
          const SizedBox(height: 16),
          const Text(
            '인증을 마치면 가입이 완료되고 자동으로 로그인돼요.\n메일이 보이지 않으면 스팸함도 확인해 주세요.',
            style: TextStyle(color: _muted, height: 1.7),
          ),
          _ErrorNotice(message: _error),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _notice!,
                  style: const TextStyle(
                    color: AppTheme.seedColor,
                    height: 1.6,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
          _SubmitButton(
            buttonKey: const ValueKey('email-verification-submit'),
            label: _usesLink
                ? _pendingPassword == null
                      ? '이메일로 로그인'
                      : '인증했어요 · 계속하기'
                : '인증하고 시작하기',
            busyLabel: '인증 확인 중',
            busy: _busy,
            onPressed: _resending ? null : _verify,
          ),
          const SizedBox(height: 12),
          TextButton(
            key: const ValueKey('email-verification-resend'),
            onPressed: _remaining > 0 || _busy || _resending ? null : _resend,
            child: Text(
              _resending
                  ? '인증 메일 보내는 중'
                  : _remaining > 0
                  ? '인증 메일 다시 보내기 · $_remaining초 후'
                  : '인증 메일 다시 보내기',
            ),
          ),
          TextButton(
            onPressed: _busy || _resending
                ? null
                : () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => EmailSignUpPage(
                        repository: widget.repository,
                        initialEmail: widget.email,
                        onAuthenticated: widget.onAuthenticated,
                      ),
                    ),
                  ),
            child: const Text('이메일 주소 수정'),
          ),
        ],
      ),
    ),
  );
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('아멘모아')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: BrandLogo(size: 56),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.seedColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: const TextStyle(color: _muted, height: 1.6),
              ),
              const SizedBox(height: 28),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

class _ConfigurationNotice extends StatelessWidget {
  const _ConfigurationNotice({required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) => configured
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EBDD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            '이메일 인증 서비스 연결이 필요해요.\n연결 전에는 인증 메일 전송과 로그인을 완료할 수 없어요.',
            style: TextStyle(height: 1.6),
          ),
        );
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: const TextStyle(color: Color(0xFF9B342F), height: 1.6),
            ),
          ),
        );
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.buttonKey,
    required this.label,
    required this.busyLabel,
    required this.busy,
    required this.onPressed,
  });

  final Key buttonKey;
  final String label;
  final String busyLabel;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
    key: buttonKey,
    onPressed: busy ? null : onPressed,
    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(child: Text(busy ? busyLabel : label)),
      ],
    ),
  );
}
