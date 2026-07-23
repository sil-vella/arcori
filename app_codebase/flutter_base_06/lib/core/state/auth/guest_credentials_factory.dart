import 'dart:math';

import '../../../utils/dev_logger.dart';
import 'contracts/local_user_storage_contract.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

const _suffixChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Generates guest credentials for first-launch auto-registration.
class GuestCredentialsFactory {
  GuestCredentialsFactory({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  StoredLocalUser generate() {
    final suffix = _randomSuffix(8);
    final username = 'guest$suffix';
    final email = '$username@arcori.arcori';
    final password = '$username${_randomDigits(6)}';
    if (LOGGING_SWITCH) {
      customlog(
        'GuestCredentialsFactory: generated guest username=$username email=$email',
      );
    }
    return StoredLocalUser(
      username: username,
      email: email,
      password: password,
      isGuest: true,
    );
  }

  String _randomSuffix(int length) {
    return List.generate(
      length,
      (_) => _suffixChars[_random.nextInt(_suffixChars.length)],
    ).join();
  }

  String _randomDigits(int length) {
    return List.generate(length, (_) => _random.nextInt(10).toString()).join();
  }
}
