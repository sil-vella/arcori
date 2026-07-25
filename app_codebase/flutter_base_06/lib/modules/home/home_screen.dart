import 'package:flutter/material.dart';

import '../../core/app_bar/app_bar_registrar.dart';
import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';

/// Body for `/` — chrome (drawer, app bar) lives in [AppShell].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBarRegistrar(
      items: const [
        AppBarTitle(text: 'Home', icon: Icons.home),
      ],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _incrementCounter,
              icon: const Icon(Icons.add),
              label: const Text('Increment'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Nav.push(context, AppPaths.velora),
              child: const Text('Velora'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Nav.push(context, AppPaths.sample),
              child: const Text('Open sample module'),
            ),
          ],
        ),
      ),
    );
  }
}
