/// Availability is only a UI check; signup must enforce uniqueness on the server.
enum EmailAvailability { available, taken, unavailable }

abstract interface class EmailAvailabilityChecker {
  bool get isConfigured;
  Future<EmailAvailability> check(String email);
}

/// Does not probe signup endpoints or claim that an email address is available.
class UnconfiguredEmailAvailabilityChecker implements EmailAvailabilityChecker {
  const UnconfiguredEmailAvailabilityChecker();

  @override
  bool get isConfigured => false;

  @override
  Future<EmailAvailability> check(String email) async =>
      EmailAvailability.unavailable;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return '이메일 주소를 입력해 주세요.';
  if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
    return '이메일 주소를 확인해 주세요.';
  }
  return null;
}
