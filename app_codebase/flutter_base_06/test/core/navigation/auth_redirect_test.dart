import 'package:flutter_test/flutter_test.dart';
import 'package:arcori/core/navigation/app_paths.dart';
import 'package:arcori/core/navigation/auth_redirect.dart';
import 'package:arcori/core/state/auth/auth_state.dart';

void main() {
  test('protected route redirects to account with from param', () {
    const auth = AuthState(sessionStatus: SessionStatus.unauthenticated);
    expect(
      redirectForAuth(Uri.parse(AppPaths.wsDemo), auth),
      '/account?from=%2Fws-demo&tab=sign-in',
    );
  });

  test('public home does not redirect', () {
    const auth = AuthState(sessionStatus: SessionStatus.unauthenticated);
    expect(redirectForAuth(Uri.parse(AppPaths.home), auth), isNull);
  });

  test('authenticated account stays on account even with from param', () {
    const auth = AuthState(
      accessToken: 'token',
      sessionStatus: SessionStatus.authenticated,
    );
    expect(
      redirectForAuth(
        Uri.parse(
          '${AppPaths.account}?from=${AppPaths.exampleModule}&tab=sign-in',
        ),
        auth,
      ),
      isNull,
    );
  });

  test('authenticated account without from stays on account', () {
    const auth = AuthState(
      accessToken: 'token',
      sessionStatus: SessionStatus.authenticated,
    );
    expect(
      redirectForAuth(Uri.parse(AppPaths.account), auth),
      isNull,
    );
  });
}
