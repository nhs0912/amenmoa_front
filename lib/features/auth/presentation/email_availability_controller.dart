import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/email_availability.dart';

enum EmailCheckStatus {
  idle,
  waiting,
  checking,
  available,
  taken,
  unavailable,
  error,
}

/// Coordinates input checks without reserving addresses or creating accounts.
class EmailAvailabilityController extends ChangeNotifier {
  EmailAvailabilityController({
    required this.checker,
    this.debounce = const Duration(seconds: 1),
  }) : assert(!debounce.isNegative);

  final EmailAvailabilityChecker checker;
  final Duration debounce;
  String _text = '';
  bool _composing = false;
  bool _disposed = false;
  int _generation = 0;
  EmailCheckStatus _status = EmailCheckStatus.idle;
  String? _checkedEmail;
  Timer? _debounceTimer;
  _PendingEmailCheck? _pending;

  EmailCheckStatus get status => _status;
  String? get checkedEmail => _checkedEmail;
  String get _email => _text.trim();
  bool get _valid => !_composing && validateEmail(_text) == null;
  bool get canSubmit =>
      !_disposed &&
      checker.isConfigured &&
      _valid &&
      _status == EmailCheckStatus.available &&
      _checkedEmail == _email;

  void updateInput(String text, {bool isComposing = false}) {
    if (_disposed || (_text == text && _composing == isComposing)) return;
    _cancelPending();
    _text = text;
    _composing = isComposing;
    if (!_valid) {
      _setStatus(EmailCheckStatus.idle);
      return;
    }
    final generation = _generation;
    final email = _email;
    _setStatus(EmailCheckStatus.waiting);
    if (!_isCurrent(generation, email)) return;
    _debounceTimer = Timer(debounce, () {
      if (!_isCurrent(generation, email)) return;
      _debounceTimer = null;
      unawaited(_check(generation, email));
    });
  }

  Future<void> retry() async {
    if (_disposed) return;
    _cancelPending();
    if (!_valid) {
      _setStatus(EmailCheckStatus.idle);
      return;
    }
    await _check(_generation, _email);
  }

  Future<void> _check(int generation, String email) async {
    if (!_isCurrent(generation, email)) return;
    if (!checker.isConfigured) {
      _setStatus(EmailCheckStatus.unavailable);
      return;
    }
    final pending = _PendingEmailCheck();
    _pending = pending;
    _setStatus(EmailCheckStatus.checking);
    try {
      if (!_isCurrent(generation, email)) return;
      pending.observe(
        Future<EmailAvailability>.sync(() => checker.check(email)),
      );
      final result = await pending.future;
      if (!_isCurrent(generation, email)) return;
      _setStatus(switch (result) {
        EmailAvailability.available => EmailCheckStatus.available,
        EmailAvailability.taken => EmailCheckStatus.taken,
        EmailAvailability.unavailable => EmailCheckStatus.unavailable,
      }, checkedEmail: result == EmailAvailability.unavailable ? null : email);
    } catch (_) {
      if (_isCurrent(generation, email)) _setStatus(EmailCheckStatus.error);
    } finally {
      pending.cancel();
      if (identical(_pending, pending)) _pending = null;
    }
  }

  bool _isCurrent(int generation, String email) =>
      !_disposed && generation == _generation && email == _email && _valid;

  void _setStatus(EmailCheckStatus status, {String? checkedEmail}) {
    if (_disposed) return;
    _status = status;
    _checkedEmail = checkedEmail;
    notifyListeners();
  }

  void _cancelPending() {
    _generation++;
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _pending?.cancel();
    _pending = null;
    _checkedEmail = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _cancelPending();
    super.dispose();
  }
}

/// Owns a cancellable timeout while continuing to consume a late request error.
class _PendingEmailCheck {
  _PendingEmailCheck() {
    _timeout = Timer(const Duration(seconds: 10), () {
      if (!_completion.isCompleted) {
        _completion.completeError(TimeoutException('Email check timed out.'));
      }
    });
  }

  final _completion = Completer<EmailAvailability>();
  late final Timer _timeout;
  Future<EmailAvailability> get future => _completion.future;

  void observe(Future<EmailAvailability> request) {
    unawaited(
      request.then<void>(
        (result) {
          if (!_completion.isCompleted) _completion.complete(result);
        },
        onError: (Object error, StackTrace stack) {
          if (!_completion.isCompleted) _completion.completeError(error, stack);
        },
      ),
    );
  }

  void cancel() {
    _timeout.cancel();
    if (!_completion.isCompleted) {
      _completion.complete(EmailAvailability.unavailable);
    }
  }
}
