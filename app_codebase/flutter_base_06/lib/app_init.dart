import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/analytics/analytics_service.dart';
import 'core/analytics/firebase_runtime_config.dart';
import 'core/app_bar/app_bar_controller.dart';
import 'core/app_bar/app_bar_registry.dart';
import 'core/bottom_nav/bottom_nav_controller.dart';
import 'core/bottom_nav/bottom_nav_registry.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/intro/intro_lottie_screen.dart';
import 'core/navigation/app_drawer_registry.dart';
import 'core/navigation/app_route_registry.dart';
import 'core/navigation/app_router.dart';
import 'core/notifications/notification_screen_registry.dart';
import 'core/notifications/response/reply_listener_registry.dart';
import 'core/notifications/subtype/subtype_registry.dart';
import 'core/state/app_state_registry.dart';
import 'core/state/auth/auth_providers.dart';
import 'core/state/auth/auth_state.dart';
import 'core/state/provider_scope_root.dart';
import 'core/state/user/user_profile_provider.dart';
import 'core/ws/app_lifecycle_observer.dart';
import 'core/ws/app_ws_coordinator.dart';
import 'firebase_options.dart';
import 'modules/auth/email_verify_deep_link.dart';
import 'modules/notifications/notification_host.dart';
import 'modules/module_registry.dart';
import 'utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

bool _bootstrapAnalyticsSent = false;

/// Builds the router, theme, and starts the Flutter app (mirrors `startApp` in dart_bkend).
Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (LOGGING_SWITCH) {
    customlog('Flutter app bootstrap');
  }
  await _initializeFirebaseIfEnabled();
  resetAppRouteRegistry();
  resetAppDrawerRegistry();
  resetAppBarRegistry();
  resetBottomNavRegistry();
  resetAppStateRegistry();
  resetNotificationScreenRegistry();
  resetNotificationSubtypeRegistry();
  resetNotificationReplyListeners();
  registerBuiltinNotificationSubtypes();
  resetAppBarController();
  resetBottomNavController();
  registerApplicationModules(
    appRouteSink,
    appDrawerSink,
    appBarSink,
    bottomNavScopeSink,
    appStateSink,
    notificationScreenSink,
  );
  appBarController.setModuleItems(appBarModuleItems);
  bottomNavController.setModuleScopes(bottomNavModuleScopes);
  runApp(const AppProviderScope(child: AppBootstrap()));
}

Future<void> _initializeFirebaseIfEnabled() async {
  if (!FirebaseRuntimeConfig.isEnabled) {
    if (LOGGING_SWITCH) {
      customlog('Firebase: skipped (FIREBASE_SWITCH off)');
    }
    return;
  }
  if (!DefaultFirebaseOptions.isCurrentPlatformConfigured) {
    if (LOGGING_SWITCH) {
      customlog('Firebase: skipped (dart-defines not configured for platform)');
    }
    return;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
    if (LOGGING_SWITCH) {
      customlog('Firebase: duplicate-app (native auto-init); continuing');
    }
  }
  if (LOGGING_SWITCH) {
    customlog('Firebase: initialized (bootstrap events deferred to first frame)');
  }
}

/// Cold-start GA4 events — after first frame so Android Activity is attached.
Future<void> sendBootstrapAnalyticsOnce() async {
  if (_bootstrapAnalyticsSent) return;
  if (!FirebaseRuntimeConfig.isEnabled) return;
  if (!DefaultFirebaseOptions.isCurrentPlatformConfigured) return;
  _bootstrapAnalyticsSent = true;
  await AnalyticsService.instance.logPlatformAppLoad();
  if (LOGGING_SWITCH) {
    customlog(
      'Firebase: bootstrap analytics sent '
      'platform=${FirebaseRuntimeConfig.appPlatform}',
    );
  }
}

/// Hydrates auth then mounts [MaterialApp.router].
class AppBootstrap extends ConsumerStatefulWidget {
  const AppBootstrap({super.key});

  @override
  ConsumerState<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends ConsumerState<AppBootstrap> {
  late bool _introFinished;

  @override
  void initState() {
    super.initState();
    _introFinished = !AppConfig.showIntroLottie;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      sendBootstrapAnalyticsOnce();
    });
    if (LOGGING_SWITCH) {
      customlog(
        'AppBootstrap: showIntroLottie=${AppConfig.showIntroLottie} '
        'introFinished=$_introFinished',
      );
    }
    Future.microtask(() async {
      if (LOGGING_SWITCH) {
        customlog('AppBootstrap: auth bootstrap started');
      }
      EmailVerifyDeepLinkHandler.bind(
        apiFactory: () => ref.read(authApiClientProvider),
        onVerified: () => ref.read(userProfileProvider.notifier).refresh(),
      );
      await ref.read(authProvider.notifier).bootstrap();
      if (!mounted) return;
      final auth = ref.read(authProvider);
      if (LOGGING_SWITCH) {
        customlog(
          'AppBootstrap: auth bootstrap finished '
          'sessionStatus=${auth.sessionStatus} '
          'isBootstrapping=${auth.isBootstrapping} '
          'isAuthenticated=${auth.isAuthenticated}',
        );
      }
      // Auth can finish after intro; ensure we leave the loading shell.
      setState(() {});
    });
  }

  void _onIntroFinished() {
    if (LOGGING_SWITCH) {
      customlog('AppBootstrap: intro finished, moving to app shell');
    }
    setState(() => _introFinished = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (!_introFinished) {
      if (LOGGING_SWITCH) {
        customlog('AppBootstrap: building IntroLottieScreen');
      }
      return MaterialApp(
        home: IntroLottieScreen(onFinished: _onIntroFinished),
      );
    }

    if (auth.isBootstrapping) {
      if (LOGGING_SWITCH) {
        customlog(
          'AppBootstrap: showing auth loading '
          'sessionStatus=${auth.sessionStatus}',
        );
      }
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.light.colorScheme.primary,
            ),
          ),
        ),
      );
    }
    if (LOGGING_SWITCH) {
      customlog(
        'AppBootstrap: mounting MaterialApp.router '
        'sessionStatus=${auth.sessionStatus}',
      );
    }
    final router = ref.watch(appRouterProvider);
    return _RootApp(router: router);
  }
}

/// Same root widget tree as production; useful in widget tests.
Widget rootAppForTesting({
  List<Override> overrides = const [],
}) {
  return AppProviderScope(
    overrides: overrides,
    child: const AppBootstrap(),
  );
}

class _RootApp extends ConsumerWidget {
  const _RootApp({required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(appWsCoordinatorProvider);

    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.isBootstrapping == true &&
          !next.isBootstrapping &&
          !next.isAuthenticated &&
          next.errorMessage != null &&
          next.errorMessage!.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.errorMessage!)),
          );
        });
      }
    });

    return AppLifecycleObserver(
      child: NotificationHost(
        child: MaterialApp.router(
          title: 'Arcori',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: router,
          builder: (context, child) {
            return _EmailVerifyDeepLinkSnackHost(child: child);
          },
        ),
      ),
    );
  }
}

class _EmailVerifyDeepLinkSnackHost extends StatefulWidget {
  const _EmailVerifyDeepLinkSnackHost({required this.child});

  final Widget? child;

  @override
  State<_EmailVerifyDeepLinkSnackHost> createState() =>
      _EmailVerifyDeepLinkSnackHostState();
}

class _EmailVerifyDeepLinkSnackHostState
    extends State<_EmailVerifyDeepLinkSnackHost> {
  @override
  void initState() {
    super.initState();
    emailVerifyDeepLinkMessage.addListener(_onMessage);
  }

  @override
  void dispose() {
    emailVerifyDeepLinkMessage.removeListener(_onMessage);
    super.dispose();
  }

  void _onMessage() {
    final message = emailVerifyDeepLinkMessage.value;
    if (message == null || message.isEmpty) return;
    emailVerifyDeepLinkMessage.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child ?? const SizedBox.shrink();
}
