import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_theme.dart';
import '../domain/session_repository.dart';
import 'brand_logo.dart';

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
  });

  final String? initialNickname;
  final Future<AppSession> Function(String nickname) onSave;
  final ValueChanged<AppSession> onCompleted;
  final VoidCallback onSignOut;
  final bool signingOut;
  final bool editing;

  @override
  State<NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<NicknamePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nickname;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nickname = TextEditingController(text: widget.initialNickname ?? '');
  }

  @override
  void dispose() {
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || widget.signingOut || !_formKey.currentState!.validate()) {
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
                                    ? Theme.of(context).colorScheme.error
                                    : const Color(0xFF6C7E74),
                              ),
                            );
                          },
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.none,
                      autofillHints: const [AutofillHints.nickname],
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '닉네임',
                        hintText: '나를 부를 이름',
                        helperText: '2~20자로 입력해 주세요.',
                        alignLabelWithHint: true,
                      ),
                      validator: validateNickname,
                      onFieldSubmitted: (_) => unawaited(_save()),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                  ),
                ),
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
                  onPressed: busy ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Text(
                          _saving
                              ? '저장하는 중'
                              : widget.editing
                              ? '닉네임 저장'
                              : '아멘모아 시작하기',
                        ),
                      ),
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
