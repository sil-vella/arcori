import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/screen/module_screen_registrar.dart';
import '../../core/state/auth/auth_providers.dart';
import 'example_module_api.dart';
import 'example_module_bottom_nav.dart';
import 'state/example_module_notifier.dart';
import '../notifications/notifications_notifier.dart';

final exampleModuleApiClientProvider = Provider<ExampleModuleApiClient>(
  (ref) => ExampleModuleApiClient(),
);

/// Cross-stack example module — tier-3 state via Riverpod + example/* WS.
class ExampleModuleScreen extends ConsumerWidget {
  const ExampleModuleScreen({super.key});

  Future<void> _sendDemoNotifications(BuildContext context, WidgetRef ref) async {
    final token = ref.read(authProvider).accessToken;
    if (token == null || token.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to send demo notifications')),
        );
      }
      return;
    }

    final outcome = await ref
        .read(exampleModuleApiClientProvider)
        .sendDemoNotifications(accessToken: token);
    if (!context.mounted) {
      return;
    }
    if (!outcome.isSuccess) {
      final message = outcome.isNetworkError
          ? 'Network error'
          : outcome.error?.message ?? 'Request failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    await ref.read(notificationsProvider.notifier).refreshAll(force: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo notifications sent — check modals or inbox'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slice = ref.watch(
      exampleModuleProvider.select((s) => (s.revision, s.message)),
    );

    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Example module', icon: Icons.extension_outlined),
      ],
      bottomNavModuleId: exampleModuleBottomNavModuleId,
      bottomNavItems: exampleModuleBottomNavItems(context),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'example_module',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Same module name on Flutter, Dart, and FastAPI. '
              'Dart hot state on example/state WS; Python durable record via service tier.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () =>
                  ref.read(exampleModuleProvider.notifier).bumpLocal(),
              child: const Text('Bump local state'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _sendDemoNotifications(context, ref),
              child: const Text('Send demo notifications'),
            ),
            const SizedBox(height: 24),
            Text(
              'Revision: ${slice.$1}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Message: ${slice.$2}'),
          ],
        ),
      ),
    );
  }
}
