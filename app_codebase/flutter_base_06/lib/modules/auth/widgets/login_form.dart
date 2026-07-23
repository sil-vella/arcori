import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';
import 'auth_form_section.dart';
import 'delete_account_modal.dart';

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    Future.microtask(_loadStoredCredentials);
  }

  Future<void> _loadStoredCredentials() async {
    final profile = await ref.read(localUserStorageProvider).read();
    if (!mounted || _prefilled || profile == null) return;
    setState(() {
      _emailController.text = profile.email;
      _passwordController.text = profile.password;
      _prefilled = true;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (ref.read(authProvider).isAuthenticated) return;
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).loginWithCredentials(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final signedIn = auth.isAuthenticated;
    final canDeleteAccount = signedIn && !auth.isGuest;

    return AuthFormSection(
      subtitle: signedIn
          ? auth.isGuest
              ? 'Signed in as guest. Use Create account to register a full account.'
              : 'You are already signed in. Sign out below to switch accounts.'
          : 'Email and password are loaded from secure storage when available.',
      errorMessage: signedIn ? null : auth.errorMessage,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailController,
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
                return null;
              },
            ),
            AppSpacing.gapMd,
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Password is required';
                }
                return null;
              },
            ),
            AppSpacing.gapLg,
            FilledButton(
              style: context.appButtons.primary.filled,
              onPressed: signedIn || auth.isLoading ? null : _submit,
              child: Text(auth.isLoading ? 'Signing in…' : 'Sign in'),
            ),
            AppSpacing.gapSm,
            OutlinedButton(
              style: context.appButtons.secondary.outlined,
              onPressed: !signedIn || auth.isLoading
                  ? null
                  : () => ref.read(authProvider.notifier).logout(),
              child: const Text('Sign out'),
            ),
            if (canDeleteAccount) ...[
              AppSpacing.gapSm,
              OutlinedButton(
                style: context.appButtons.error.outlined,
                onPressed: auth.isLoading
                    ? null
                    : () => showDeleteAccountModal(context),
                child: const Text('Delete account'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
