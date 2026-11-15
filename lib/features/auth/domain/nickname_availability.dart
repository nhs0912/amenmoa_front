/// A display-name availability check is advisory. The future backend must also
/// enforce uniqueness atomically when saving; a check cannot reserve a nickname.
enum NicknameAvailability { available, taken, unavailable }

/// Implement this with the future backend API backed by a database or Redis.
/// [nickname] is trimmed by the caller. The backend owns normalization rules and
/// identifies the current user from authentication when excluding their own name.
abstract interface class NicknameAvailabilityChecker {
  bool get isConfigured;
  Future<NicknameAvailability> check(String nickname);
}

/// No backend has been configured yet. Never pretend a nickname is available.
/// New or changed nicknames cannot be saved until a real checker is connected.
class UnconfiguredNicknameAvailabilityChecker
    implements NicknameAvailabilityChecker {
  const UnconfiguredNicknameAvailabilityChecker();

  @override
  bool get isConfigured => false;

  @override
  Future<NicknameAvailability> check(String nickname) async =>
      NicknameAvailability.unavailable;
}
