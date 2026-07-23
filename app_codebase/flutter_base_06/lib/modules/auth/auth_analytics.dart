import '../../core/analytics/analytics_service.dart';

/// GA4 events for auth / guest → full account flows.
class AuthAnalytics {
  AuthAnalytics._();

  static Future<void> logGuestBootstrapCreated() =>
      AnalyticsService.instance.logEvent('account_guest_bootstrap_created');

  /// User submitted Create account / Convert to full account on Account screen.
  static Future<void> logFullAccountCreateAttempt({
    required String flow,
  }) =>
      AnalyticsService.instance.logEvent(
        'account_full_create_attempt',
        parameters: {'flow': flow},
      );

  static Future<void> logGuestConvertSuccess() =>
      AnalyticsService.instance.logEvent('account_guest_convert_success');

  static Future<void> logLoginAttempt() =>
      AnalyticsService.instance.logEvent('account_login_attempt');

  static Future<void> logLoginSuccess() =>
      AnalyticsService.instance.logEvent('account_login_success');
}
