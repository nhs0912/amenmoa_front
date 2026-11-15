import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/nickname_availability.dart';
import '../domain/session_repository.dart';
import 'availability_input_decoration.dart';
import 'brand_logo.dart';
import 'nickname_availability_controller.dart';

/// Collects the authenticated user's profile name before opening the app.
/// The page delegates persistence to the account repository through [onSave].
class NicknamePage extends StatefulWidget {
  const NicknamePage({
    super.key,
    this.initialNickname,
    required this.onSave,
    required this.onCompleted,
    required this.onSignOut,
    this.signingOut = false,
    this.editing = false,
    this.availabilityChecker = const UnconfiguredNicknameAvailabilityChecker(),
  });

  final String? initialNickname;
  final Future<AppSession> Function(String nickname) onSave;
  final ValueChanged<AppSession> onCompleted;
  final VoidCallback onSignOut;
  final bool signingOut;
  final bool editing;
  final NicknameAvailabilityChecker availabilityChecker;

  @override
  State<NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<NicknamePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  late NicknameAvailabilityController _availability;
  bool _saving = false;
  String? _error;

  static const _successColor = availabilitySuccessColor;
  static const _failureColor = availabilityFailureColor;
  static const _neutralColor = availabilityNeutralColor;

  bool get _checkSucceeded =>
      _availability.status == NicknameCheckStatus.available ||
      _availability.status == NicknameCheckStatus.unchanged;

  bool get _checkFailed =>
      _availability.status == NicknameCheckStatus.taken ||
      _availability.status == NicknameCheckStatus.error ||
      (_availability.status == NicknameCheckStatus.unavailable &&
          widget.availabilityChecker.isConfigured);

  InputDecoration _nicknameDecoration() => availabilityInputDecoration(
    labelText: '닉네임',
    hintText: '나를 부를 이름',
    helperText: '2~20자로 입력해 주세요.',
    state: _availability.status == NicknameCheckStatus.checking
        ? AvailabilityInputState.checking
        : _checkSucceeded
        ? AvailabilityInputState.available
        : _checkFailed
        ? AvailabilityInputState.invalid
        : AvailabilityInputState.neutral,
    checkingSemanticLabel: '닉네임 중복 확인 중',
    successSemanticLabel: _availability.status == NicknameCheckStatus.unchanged
        ? '현재 사용 중인 닉네임'
        : '사용 가능한 닉네임',
    failureSemanticLabel: '닉네임 확인 필요',
  );

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.initialNickname ?? '');
    _setUpAvailability();
    _nickname.addListener(_handleInputChanged);
  }

  void _setUpAvailability() {
    _availability = NicknameAvailabilityController(
      checker: widget.availabilityChecker,
      initialNickname: widget.editing ? widget.initialNickname : null,
      editing: widget.editing,
    );
    _availability.addListener(_handleAvailabilityChanged);
    _handleInputChanged();
  }

  void _handleInputChanged() {
    final value = _nickname.value;
    _availability.updateInput(
      value.text,
      isComposing: value.composing.isValid && !value.composing.isCollapsed,
    );
  }

  void _handleAvailabilityChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant NicknamePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availabilityChecker != widget.availabilityChecker ||
        oldWidget.initialNickname != widget.initialNickname ||
        oldWidget.editing != widget.editing) {
      _availability.removeListener(_handleAvailabilityChanged);
      _availability.dispose();
      _setUpAvailability();
    }
  }

  @override
  void dispose() {
    _nickname.removeListener(_handleInputChanged);
    _availability.removeListener(_handleAvailabilityChanged);
    _availability.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        widget.signingOut ||
        !_formKey.currentState!.validate() ||
        !_availability.canSave) {
      return;
    }
    final nickname = _nickname.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = await widget.onSave(nickname);
      if (!mounted) return;
      widget.onCompleted(session);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is AuthFailure
            ? error.message
            : '닉네임을 저장하지 못했어요. 연결 상태를 확인하고 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildAvailabilityStatus(bool busy) {
    final status = _availability.status;
    final configured = widget.availabilityChecker.isConfigured;
    final pending = status == NicknameCheckStatus.checking;
    final retryable =
        status == NicknameCheckStatus.error ||
        (status == NicknameCheckStatus.unavailable && configured);
    final Color color;
    final String? message;
    final IconData icon;
    switch (status) {
      case NicknameCheckStatus.idle:
        color = const Color(0xFF6C7E74);
        icon = Icons.info_outline;
        message = configured ? null : '중복 확인 연결을 준비 중이에요.';
      case NicknameCheckStatus.waiting:
        color = const Color(0xFF6C7E74);
        icon = Icons.hourglass_empty;
        message = '입력이 끝나면 중복을 확인할게요.';
      case NicknameCheckStatus.checking:
        color = const Color(0xFF6C7E74);
        icon = Icons.hourglass_empty;
        message = '중복 확인 중…';
      case NicknameCheckStatus.available:
        color = _successColor;
        icon = Icons.check_circle_outline;
        message = '사용할 수 있는 닉네임이에요.';
      case NicknameCheckStatus.taken:
        color = _failureColor;
        icon = Icons.error_outline;
        message = '이미 사용 중인 닉네임이에요.';
      case NicknameCheckStatus.unavailable:
        color = configured ? _failureColor : _neutralColor;
        icon = configured ? Icons.error_outline : Icons.info_outline;
        message = configured
            ? '지금은 중복을 확인할 수 없어요. 다시 확인해 주세요.'
            : '중복 확인 연결을 준비 중이에요.';
      case NicknameCheckStatus.error:
        color = _failureColor;
        icon = Icons.error_outline;
        message = '중복 확인 중 오류가 발생했어요. 다시 시도해 주세요.';
      case NicknameCheckStatus.unchanged:
        color = _successColor;
        icon = Icons.check_circle_outline;
        message = '현재 사용 중인 닉네임이에요.';
    }
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            liveRegion: true,
            child: Row(
              key: const ValueKey('nickname-availability-status'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pending)
                  const SizedBox(width: 26)
                else ...[
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: color, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          if (retryable)
            TextButton(
              key: const ValueKey('nickname-availability-retry'),
              onPressed: busy ? null : () => unawaited(_availability.retry()),
              child: const Text('다시 확인'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final busy = _saving || widget.signingOut;
    return Scaffold(
      key: const ValueKey('nickname-screen'),
      appBar: widget.editing ? AppBar(title: const Text('닉네임 수정')) : null,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                28,
                keyboardVisible ? 24 : 40,
                28,
                keyboardVisible ? 24 : 36,
              ),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BrandLogo(size: 64),
                ),
                const SizedBox(height: 28),
                const Text(
                  '어떻게 불러드릴까요?',
                  style: TextStyle(
                    color: AppTheme.seedColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '아멘모아에서 사용할 이름을 알려 주세요.',
                  style: TextStyle(color: Color(0xFF6C7E74), height: 1.7),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: TextFormField(
                      key: const ValueKey('nickname-input'),
                      controller: _nickname,
                      autofocus: true,
                      enabled: !busy,
                      maxLines: 1,
                      maxLength: 20,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      buildCounter:
                          (
                            context, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) {
                            final length = _nickname.text
                                .trim()
                                .characters
                                .length;
                            return Text(
                              '$length/20',
                              semanticsLabel: '닉네임 $length자, 최대 20자',
                              style: TextStyle(
                                color: length > 20
                                    ? _failureColor
                                    : const Color(0xFF6C7E74),
                              ),
                            );
                          },
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.nickname],
                      autocorrect: false,
                      decoration: _nicknameDecoration(),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      validator: validateNickname,
                      onFieldSubmitted: (_) => unawaited(_save()),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                ),
                _buildAvailabilityStatus(busy),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFF9B342F),
                        height: 1.6,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('nickname-submit'),
                  onPressed: busy || !_availability.canSave ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    disabledBackgroundColor: const Color(0xFFE3E9E3),
                    disabledForegroundColor: const Color(0xFF849389),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_saving) ...[
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.seedColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(child: Text(_saving ? '저장하는 중' : '닉네임 저장')),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: busy ? null : widget.onSignOut,
                  child: Text(widget.signingOut ? '로그아웃하는 중' : '다른 계정으로 로그인'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
