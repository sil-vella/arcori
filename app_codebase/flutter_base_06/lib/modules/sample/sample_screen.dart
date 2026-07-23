import 'package:flutter/material.dart';

import '../../core/app_bar/app_bar_registrar.dart';
import '../../core/app_bar/contracts/register_app_bar_contract.dart';

/// Body for `/sample` — chrome lives in [AppShell].
class SampleScreen extends StatelessWidget {
  const SampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBarRegistrar(
      items: const [
        AppBarTitle(
          text: 'Sample module',
          icon: Icons.widgets_outlined,
        ),
      ],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.widgets_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Sample feature',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This screen is registered from lib/modules/sample/ '
                'via the shared route sink. Use the drawer or back button '
                'to navigate.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
