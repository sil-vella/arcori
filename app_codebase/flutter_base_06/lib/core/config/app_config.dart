/// App-wide flags from dart-define (.env.dart.defines.* via wfrun launch scripts).
class AppConfig {
  const AppConfig._();

  static const _showIntroLottieRaw = String.fromEnvironment('SHOW_INTRO_LOTTIE');

  /// Full-screen intro Lottie after native splash; off unless SHOW_INTRO_LOTTIE is truthy.
  static bool get showIntroLottie => isEnvTruthy(_showIntroLottieRaw);

  static const introLottieAsset = 'assets/lottie/intro.json';
}

const _envTruthy = {'1', 'true', 'yes'};

bool isEnvTruthy(String? raw) =>
    _envTruthy.contains((raw ?? '').trim().toLowerCase());
