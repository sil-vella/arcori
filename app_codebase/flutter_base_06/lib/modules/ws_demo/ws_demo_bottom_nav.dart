import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bottom_nav/contracts/register_bottom_nav_contract.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/state/auth/auth_providers.dart';
import '../../core/ws/ws_config.dart';
import '../../core/ws/ws_connection_manager.dart';

const wsDemoBottomNavModuleId = 'ws_demo';

void registerWsDemoBottomNavScope(BottomNavScopeSink sink) {
  sink.registerScope(
    moduleId: wsDemoBottomNavModuleId,
    pathPrefixes: [AppPaths.wsDemo],
  );
}

List<BottomNavItem> wsDemoBottomNavItems(
  BuildContext context,
  WidgetRef ref,
) {
  final auth = ref.watch(authProvider);
  final ws = ref.watch(wsConnectionManagerProvider);
  final manager = ref.read(wsConnectionManagerProvider.notifier);

  const dartId = 'dart';
  const apiId = 'api';

  final dartConnected = ws.connections[dartId] ?? false;
  final apiConnected = ws.connections[apiId] ?? false;

  return [
    BottomNavAction(
      icon: Icons.link,
      tooltip: 'Connect both WS',
      onTap: () async {
        if (!auth.isAuthenticated) {
          return;
        }
        await manager.connect(
          dartId,
          url: WsConfig.dartAuthuserUrl,
          accessToken: auth.accessToken,
        );
        await manager.connect(
          apiId,
          url: WsConfig.apiAuthuserUrl,
          accessToken: auth.accessToken,
        );
      },
      visibleWhen: (_) => auth.isAuthenticated,
    ),
    BottomNavAction(
      icon: Icons.network_ping,
      tooltip: 'Ping Dart',
      onTap: () => manager.send(dartId, type: 'ping', channel: 'system'),
      visibleWhen: (_) => dartConnected,
    ),
    BottomNavAction(
      icon: Icons.cloud_outlined,
      tooltip: 'Ping API',
      onTap: () => manager.send(apiId, type: 'ping', channel: 'system'),
      visibleWhen: (_) => apiConnected,
    ),
  ];
}
