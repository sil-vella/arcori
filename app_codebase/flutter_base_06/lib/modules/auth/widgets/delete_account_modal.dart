import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/modal/modal.dart';
import '../../../core/state/auth/auth_providers.dart';
import '../../../core/theme/theme.dart';

/// Centered confirmation modal — type DELETE + password to delete account.
Future<bool> showDeleteAccountModal(BuildContext context) {
  return AppModal.showCentered<bool>(
    context,
    barrierDismissible: false,
    builder: (dialogContext) => const _DeleteAccountModal(),
  ).then((value) => value ?? false);
}

class _DeleteAccountModal extends ConsumerStatefulWidget {
  const _DeleteAccountModal();

  @override
  ConsumerState<_DeleteAccountModal> createState() =>
      _DeleteAccountModalState();
}

class _DeleteAccountModalState extends ConsumerState<_DeleteAccountModal> {
  final _confirmationController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    return _confirmationController.text.trim() == 'DELETE' &&
        _passwordController.text.trim().isNotEmpty &&
        !ref.read(authProvider).isLoading;
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _errorMessage = null);
    final ok = await ref.read(authProvider.notifier).deleteAccount(
          password: _passwordController.text,
          confirmation: _confirmationController.text,
        );
    if (!mounted) return;
    if (ok) {
      AppModal.dismiss(context, true);
      return;
    }
    setState(() {
      _errorMessage = ref.read(authProvider).errorMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return AppCenteredModal(
      title: 'Delete account?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This permanently removes your account and cannot be undone.',
            style: context.appTypography.bodyMuted,
          ),
          AppSpacing.gapMd,
          TextFormField(
            controller: _confirmationController,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type DELETE to confirm',
              hintText: 'DELETE',
            ),
            onChanged: (_) => setState(() {}),
          ),
          AppSpacing.gapMd,
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
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
          ),
          if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
            AppSpacing.gapSm,
            Text(
              _errorMessage!,
              style: context.appTypography.body.copyWith(
                color: context.appColors.red,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: auth.isLoading
              ? null
              : () => AppModal.dismiss(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: context.appButtons.error.filled,
          onPressed: _canSubmit ? _submit : null,
          child: Text(auth.isLoading ? 'Deleting…' : 'Delete account'),
        ),
      ],
    );
  }
}
