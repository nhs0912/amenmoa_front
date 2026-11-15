import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/nickname_availability.dart';
import '../domain/session_repository.dart';

enum NicknameCheckStatus {
  idle,
  waiting,
  checking,
  available,
  taken,
  unavailable,
  error,
  unchanged,
}

/// Debounces UI input without claiming uniqueness when no checker is configured.
/// This controller does not own a database connection or reserve nicknames.
class NicknameAvailabilityController extends ChangeNotifier {
  NicknameAvailabilityController({
    required this.checker,
    String? initialNickname,
    this.editing = false,
    this.debounce = const Duration(seconds: 1),
  }) : assert(!debounce.isNegative),
       _text = initialNickname ?? '',
       _originalNickname = editing && validateNickname(initialNickname) == null
           ? initialNickname!.trim()
           : null {
    if (_isUnchanged) {
      _status = NicknameCheckStatus.unchanged;
      _checkedNickname = _canonical;
    }
  }

  final NicknameAvailabilityChecker checker;
  final bool editing;
  final Duration debounce;
  final String? _originalNickname;
  static const _requestTimeout = Duration(seconds: 10);

  String _text;
  bool _isComposing = false;
  bool _disposed = false;
  int _generation = 0;
  NicknameCheckStatus _status = NicknameCheckStatus.idle;
  String? _checkedNickname;
  Timer? _debounceTimer;
  Timer? _timeoutTimer;
  Completer<NicknameAvailability>? _activeCompletion;

  NicknameCheckStatus get status => _status;
  String? get checkedNickname => _checkedNickname;
  String get _canonical => _text.trim();
  bool get _hasValidInput => !_isComposing && validateNickname(_text) == null;
  bool get _isUnchanged =>
      editing && _originalNickname != null && _canonical == _originalNickname;

  bool get canSave {
    if (_disposed || !_hasValidInput) return false;
    if (!checker.isConfigured) return true;
    return (_status == NicknameCheckStatus.unchanged && _isUnchanged) ||
        (_status == NicknameCheckStatus.available &&
            _checkedNickname == _canonical);
  }

  void updateInput(String text, {bool isComposing = false}) {
    if (_disposed || (_text == text && _isComposing == isComposing)) return;
    _cancelPending();
    _text = text;
    _isComposing = isComposing;
    if (!_hasValidInput) {
      _setStatus(NicknameCheckStatus.idle);
      return;
    }
    if (_isUnchanged) {
      _setStatus(NicknameCheckStatus.unchanged, checkedNickname: _canonical);
      return;
    }
    final generation = _generation;
    final nickname = _canonical;
    _setStatus(NicknameCheckStatus.waiting);
    // A listener may synchronously change the input while being notified.
    if (!_isCurrent(generation, nickname)) return;
    _debounceTimer = Timer(debounce, () {
      if (!_isCurrent(generation, nickname)) return;
      _debounceTimer = null;
      unawaited(_check(generation, nickname));
    });
  }

  Future<void> retry() async {
    if (_disposed) return;
    _cancelPending();
    if (!_hasValidInput) {
      _setStatus(NicknameCheckStatus.idle);
      return;
    }
    if (_isUnchanged) {
      _setStatus(NicknameCheckStatus.unchanged, checkedNickname: _canonical);
      return;
    }
    await _check(_generation, _canonical);
  }

  Future<void> _check(int generation, String nickname) async {
    if (!_isCurrent(generation, nickname)) return;
    if (!checker.isConfigured) {
      _setStatus(NicknameCheckStatus.unavailable);
      return;
    }

    final completion = Completer<NicknameAvailability>();
    _activeCompletion = completion;
    final timeout = Timer(_requestTimeout, () {
      if (!completion.isCompleted) {
        completion.completeError(TimeoutException('Nickname check timed out.'));
      }
    });
    _timeoutTimer = timeout;
    _setStatus(NicknameCheckStatus.checking);
    try {
      if (!_isCurrent(generation, nickname)) return;
      // Handle both synchronous throws and later errors, including responses
      // that arrive after cancellation or disposal.
      unawaited(
        Future<NicknameAvailability>.sync(
          () => checker.check(nickname),
        ).then<void>(
          (result) {
            if (!completion.isCompleted) completion.complete(result);
          },
          onError: (Object error, StackTrace stack) {
            if (!completion.isCompleted) completion.completeError(error, stack);
          },
        ),
      );
      final result = await completion.future;
      if (!_isCurrent(generation, nickname)) return;
      switch (result) {
        case NicknameAvailability.available:
          _setStatus(NicknameCheckStatus.available, checkedNickname: nickname);
        case NicknameAvailability.taken:
          _setStatus(NicknameCheckStatus.taken, checkedNickname: nickname);
        case NicknameAvailability.unavailable:
          _setStatus(NicknameCheckStatus.unavailable);
      }
    } catch (_) {
      if (_isCurrent(generation, nickname)) {
        _setStatus(NicknameCheckStatus.error);
      }
    } finally {
      timeout.cancel();
      if (identical(_activeCompletion, completion)) {
        _activeCompletion = null;
        _timeoutTimer = null;
      }
    }
  }

  bool _isCurrent(int generation, String nickname) =>
      !_disposed &&
      generation == _generation &&
      nickname == _canonical &&
      _hasValidInput;

  void _setStatus(NicknameCheckStatus status, {String? checkedNickname}) {
    if (_disposed) return;
    _status = status;
    _checkedNickname = checkedNickname;
    notifyListeners();
  }

  void _cancelPending() {
    _generation++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    final active = _activeCompletion;
    _activeCompletion = null;
    // Settle retry() callers while leaving the underlying request harmlessly
    // observed. Generation checks ensure this cannot become a visible result.
    if (active != null && !active.isCompleted) {
      active.complete(NicknameAvailability.unavailable);
    }
    _checkedNickname = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelPending();
    super.dispose();
  }
}
