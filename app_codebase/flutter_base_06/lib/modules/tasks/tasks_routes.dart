import 'package:go_router/go_router.dart';

import '../../core/navigation/app_paths.dart';
import '../../core/navigation/contracts/register_route_contract.dart';
import '../../core/notifications/contracts/register_notification_screen_contract.dart';
import 'screens/task_detail_screen.dart';
import 'screens/tasks_screen.dart';

void registerTasksRoutes(
  AppRouteSink routes,
  NotificationScreenSink notificationScreens,
) {
  notificationScreens.registerScreens([
    const NotificationNavigableScreen(
      slug: 'tasks',
      path: AppPaths.tasks,
    ),
    const NotificationNavigableScreen(
      slug: 'daily_goals',
      path: AppPaths.tasks,
    ),
  ]);

  routes.addRoutes([
    GoRoute(
      path: AppPaths.tasks,
      name: 'tasks',
      builder: (context, state) => const TasksScreen(),
    ),
    GoRoute(
      path: AppPaths.taskDetail,
      name: 'taskDetail',
      builder: (context, state) {
        final id = state.uri.queryParameters['id']?.trim() ?? '';
        return TaskDetailScreen(taskId: id);
      },
    ),
  ]);
}
