import '../core/errors/module_error_registry.dart';
import '../core/http/response/response.dart';
import '../core/http/service/routes.dart';
import '../core/state/state_registry.dart';
import '../core/ws/service/channel_registry.dart';
import 'auth/auth_app.dart';
import 'example_module/example_app.dart';
import 'example_module/example_errors.dart';
import 'example_module/example_store.dart';
import 'match/match_app.dart';
import 'match/match_errors.dart';
import 'match/match_store.dart';
import 'matchmaking/matchmaking_app.dart';
import 'matchmaking/matchmaking_errors.dart';
import 'matchmaking/matchmaking_service.dart';
import 'ops/ops_app.dart';
import 'ops/ops_errors.dart';
import 'ops/ops_state.dart';
import 'service/service_app.dart';
import 'user/user_app.dart';
import 'ws/demo_errors.dart';
import 'ws/demo_ws_app.dart';

void registerApplicationRoutes() {
  registerUserRoutes(applicationRoutes, httpResponses);
  registerServiceRoutes(applicationRoutes, httpResponses);
  registerOpsRoutes(applicationRoutes, httpResponses);
  registerAuthRoutes(applicationRoutes, httpResponses);
}

void registerApplicationErrors() {
  registerDemoErrors(moduleErrorRegistrar);
  registerExampleModuleErrors(moduleErrorRegistrar);
  registerMatchErrors(moduleErrorRegistrar);
  registerMatchmakingErrors(moduleErrorRegistrar);
  registerOpsErrors(moduleErrorRegistrar);
}

void registerApplicationState() {
  resetStateRegistry();
  resetExampleModuleState();
  resetMatchState();
  resetMatchmakingState();
  resetOpsState();
}

void registerApplicationWsChannels() {
  registerDemoWsChannels(applicationWsSink);
  registerExampleModuleWsChannels(applicationWsSink);
  registerMatchWsChannels(applicationWsSink);
  registerMatchmakingWsChannels(applicationWsSink);
}
