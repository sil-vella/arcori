import '../core/app_bar/contracts/register_app_bar_contract.dart';
import '../core/bottom_nav/contracts/register_bottom_nav_contract.dart';
import '../core/navigation/contracts/register_drawer_contract.dart';
import '../core/navigation/contracts/register_route_contract.dart';
import '../core/notifications/contracts/register_notification_screen_contract.dart';
import '../core/state/contracts/app_state_sink.dart';
import '../core/state/register_core_state.dart';
import 'example_module/example_module_bottom_nav.dart';
import 'example_module/example_module_routes.dart';
import 'example_module/register_example_module_state.dart';
import 'home/home_drawer.dart';
import 'home/home_routes.dart';
import 'auth/auth_drawer.dart';
import 'auth/auth_routes.dart';
import 'avari/avari_drawer.dart';
import 'avari/avari_routes.dart';
import 'match/register_match_state.dart';
import 'matchmaking/register_matchmaking_state.dart';
import 'notifications/notifications_drawer.dart';
import 'notifications/notifications_routes.dart';
import 'notifications/register_notifications_state.dart';
import 'play/play_drawer.dart';
import 'play/play_routes.dart';
import 'play/register_play_notifications.dart';
import 'sample/sample_routes.dart';
import 'velora/velora_drawer.dart';
import 'velora/velora_routes.dart';
import 'ws_demo/ws_demo_bottom_nav.dart';
import 'ws_demo/ws_demo_routes.dart';
import 'ws_demo/ws_demo_state.dart';

void registerApplicationModules(
  AppRouteSink routes,
  AppDrawerSink drawer,
  AppBarSink appBar,
  BottomNavScopeSink bottomNav,
  AppStateSink state,
  NotificationScreenSink notificationScreens,
) {
  registerCoreState(state);
  registerWsDemoState(state);
  registerExampleModuleState(state);
  registerMatchState(state);
  registerMatchmakingState(state);
  registerNotificationsState(state);

  registerHomeRoutes(routes, notificationScreens);
  registerHomeDrawer(drawer);
  registerAuthRoutes(routes, notificationScreens);
  registerAuthDrawer(drawer);
  registerAvariRoutes(routes, notificationScreens);
  registerAvariDrawer(drawer);
  registerPlayRoutes(routes, notificationScreens);
  registerPlayNotifications();
  registerPlayDrawer(drawer);
  registerSampleRoutes(routes, notificationScreens);
  registerWsDemoRoutes(routes, notificationScreens);
  registerWsDemoBottomNavScope(bottomNav);
  registerExampleModuleRoutes(routes, notificationScreens);
  registerExampleModuleBottomNavScope(bottomNav);
  registerNotificationsRoutes(routes, notificationScreens);
  registerNotificationsDrawer(drawer);
  registerVeloraRoutes(routes, notificationScreens);
  registerVeloraDrawer(drawer);
}
