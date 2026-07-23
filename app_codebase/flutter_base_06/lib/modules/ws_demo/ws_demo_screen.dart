import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_bar/app_bar_registrar.dart';
import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/bottom_nav/bottom_nav_registrar.dart';
import 'ws_demo_bottom_nav.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../core/ws/ws_connection_manager.dart';
import 'state/ws_demo_log_notifier.dart';
import 'state/ws_demo_subscriptions_notifier.dart';

class WsDemoScreen extends ConsumerWidget {
  const WsDemoScreen({super.key});

  static const _dartId = 'dart';
  static const _apiId = 'api';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final ws = ref.watch(wsConnectionManagerProvider);
    final demoLog = ref.watch(wsDemoLogProvider);
    final manager = ref.read(wsConnectionManagerProvider.notifier);

    return BottomNavRegistrar(
      moduleId: wsDemoBottomNavModuleId,
      items: wsDemoBottomNavItems(context, ref),
      child: AppBarRegistrar(
      items: const [
        AppBarTitle(text: 'WebSocket Demo'),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'WebSocket demo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            auth.isAuthenticated
                ? 'Signed in as ${auth.userId}. Connects to Dart and FastAPI /ws/authuser.'
                : 'Sign in required — open Account from the drawer.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: !auth.isAuthenticated
                    ? null
                    : () async {
                        await manager.connect(
                          _dartId,
                          url: WsConfig.dartAuthuserUrl,
                          accessToken: auth.accessToken,
                        );
                        await manager.connect(
                          _apiId,
                          url: WsConfig.apiAuthuserUrl,
                          accessToken: auth.accessToken,
                        );
                      },
                child: const Text('Connect both WS'),
              ),
              OutlinedButton(
                onPressed: () => manager.send(
                  _dartId,
                  type: 'ping',
                  channel: 'system',
                ),
                child: const Text('Ping Dart'),
              ),
              OutlinedButton(
                onPressed: () => manager.send(
                  _apiId,
                  type: 'ping',
                  channel: 'system',
                ),
                child: const Text('Ping API'),
              ),
              OutlinedButton(
                onPressed: () => manager.send(
                  _dartId,
                  type: 'event',
                  channel: 'demo/echo',
                  payload: {'text': 'hello from Dart'},
                ),
                child: const Text('Echo Dart'),
              ),
              OutlinedButton(
                onPressed: () => manager.send(
                  _apiId,
                  type: 'event',
                  channel: 'demo/echo',
                  payload: {'text': 'hello from API'},
                ),
                child: const Text('Echo API'),
              ),
              OutlinedButton(
                onPressed: () async {
                  const roomId = 'demo';
                  ref
                      .read(wsDemoSubscriptionsProvider.notifier)
                      .subscribeRoom(_dartId, roomId);
                  await manager.send(
                    _dartId,
                    type: 'subscribe',
                    channel: 'demo/room',
                    payload: {'room_id': roomId},
                  );
                },
                child: const Text('Subscribe room (Dart)'),
              ),
              OutlinedButton(
                onPressed: () async {
                  const roomId = 'demo';
                  ref
                      .read(wsDemoSubscriptionsProvider.notifier)
                      .subscribeRoom(_apiId, roomId);
                  await manager.send(
                    _apiId,
                    type: 'subscribe',
                    channel: 'demo/room',
                    payload: {'room_id': roomId},
                  );
                },
                child: const Text('Subscribe room (API)'),
              ),
              OutlinedButton(
                onPressed: () => manager.send(
                  _dartId,
                  type: 'event',
                  channel: 'demo/room',
                  payload: {'room_id': 'demo', 'text': 'hello room'},
                ),
                child: const Text('Room message (Dart)'),
              ),
              OutlinedButton(
                onPressed: () => ref.read(authProvider.notifier).logout(),
                child: const Text('Logout'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Connection log', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...ws.log.take(10).map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
          if (demoLog.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Demo channel', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...demoLog.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  line,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}
