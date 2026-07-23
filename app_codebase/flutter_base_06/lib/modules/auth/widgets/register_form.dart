import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/navigation/app_paths.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import '../../../utils/dev_logger.dart';
import '../auth_analytics.dart';
import 'auth_form_section.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

class RegisterForm extends ConsumerStatefulWidget {
  const RegisterForm({
    super.key,
    this.onConvertSuccess,
  });

  final VoidCallback? onConvertSuccess;

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated && !auth.isGuest) return;
    if (!_formKey.currentState!.validate()) return;
    final isConvertMode = auth.isAuthenticated && auth.isGuest;

    await AuthAnalytics.logFullAccountCreateAttempt(
      flow: isConvertMode ? 'guest_convert' : 'register',
    );

    final ok = isConvertMode
        ? await _submitConvert()
        : await ref.read(authProvider.notifier).registerAccount(
              username: _usernameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            );
    if (!mounted) return;
    if (!ok) return;
    if (isConvertMode) {
      widget.onConvertSuccess?.call();
      return;
    }
    context.go(AppPaths.home);
  }

  Future<bool> _submitConvert() async {
    final profile = await ref.read(localUserStorageProvider).read();
    if (profile == null) {
      if (LOGGING_SWITCH) {
        customlog('RegisterForm: convert submit — no local guest profile');
      }
      return false;
    }
    if (LOGGING_SWITCH) {
      customlog(
        'RegisterForm: convert submit guestEmail=${profile.email} '
        'newEmail=${_emailController.text.trim()} '
        'username=${_usernameController.text.trim()}',
      );
    }
    return ref.read(authProvider.notifier).convertGuestAccount(
          guestEmail: profile.email,
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isConvertMode = auth.isAuthenticated && auth.isGuest;
    final isFullAccountSignedIn = auth.isAuthenticated && !auth.isGuest;

    final subtitle = isFullAccountSignedIn
        ? 'You are already signed in with a full account. Sign out on the '
            'Sign in tab to switch accounts.'
        : isConvertMode
            ? 'Upgrade your guest account. Your user id and saved data stay the same — '
                'choose a personal email and password.'
            : 'Create a full account. Stored guest credentials on this device '
                'will be replaced.';
    final buttonLabel = isConvertMode
        ? (auth.isLoading ? 'Converting…' : 'Convert to full account')
        : (auth.isLoading ? 'Creating account…' : 'Create account');

    return AuthFormSection(
      subtitle: subtitle,
      errorMessage: isFullAccountSignedIn ? null : auth.errorMessage,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _usernameController,
              enabled: !isFullAccountSignedIn,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'yourname',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Username is required';
                if (text.length > 64) return 'Username is too long';
                return null;
              },
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _emailController,
              enabled: !isFullAccountSignedIn,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'you@example.com',
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Email is required';
                if (!text.contains('@')) return 'Enter a valid email';
                if (text.endsWith('@arcori.arcori')) {
                  return 'Choose a personal email address';
                }
                return null;
              },
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _passwordController,
              enabled: !isFullAccountSignedIn,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: isFullAccountSignedIn
                      ? null
                      : () => setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Password is required';
                if (text.length < 6) return 'Use at least 6 characters';
                return null;
              },
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _confirmPasswordController,
              enabled: !isFullAccountSignedIn,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Confirm password',
                suffixIcon: IconButton(
                  onPressed: isFullAccountSignedIn
                      ? null
                      : () => setState(() => _obscureConfirm = !_obscureConfirm),
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            AppSpacing.gapLg,
            FilledButton(
              style: context.appButtons.primary.filled,
              onPressed: isFullAccountSignedIn || auth.isLoading ? null : _submit,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
