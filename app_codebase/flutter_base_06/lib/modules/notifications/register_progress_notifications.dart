import '../../core/notifications/subtype/notification_subtype_spec.dart';
import '../../core/notifications/subtype/subtype_registry.dart';

const _achievementsSource = 'achievements';
const _dailyGoalsSource = 'daily_goals';
const _legacySource = 'legacy';

/// Achievement unlock + daily complete + legacy offer instant subtypes.
void registerProgressNotifications() {
  notificationSubtypeSink.registerSubtypes([
    const NotificationSubtypeSpec(
      source: _achievementsSource,
      category: 'progress',
      subtype: 'unlock_v1',
      allowedScreens: {
        'achievements',
        'avari',
        'tasks',
        'daily_goals',
        'home',
        'play',
      },
      modalPriority: 40,
    ),
    const NotificationSubtypeSpec(
      source: _dailyGoalsSource,
      category: 'progress',
      subtype: 'complete_v1',
      allowedScreens: {
        'tasks',
        'daily_goals',
        'achievements',
        'home',
        'play',
      },
      modalPriority: 45,
    ),
    const NotificationSubtypeSpec(
      source: _legacySource,
      category: 'progress',
      subtype: 'offer_v1',
      allowedScreens: {
        'avari',
        'play',
        'home',
        'tasks',
      },
      modalPriority: 35,
    ),
    const NotificationSubtypeSpec(
      source: _legacySource,
      category: 'progress',
      subtype: 'pressure_v1',
      allowedScreens: {
        'play',
        'avari',
        'home',
      },
      modalPriority: 38,
    ),
    const NotificationSubtypeSpec(
      source: _legacySource,
      category: 'progress',
      subtype: 'chase_v1',
      allowedScreens: {
        'play',
        'avari',
        'home',
      },
      modalPriority: 38,
    ),
  ]);
}

bool isAchievementUnlockNotification({
  required String source,
  String? subtype,
}) {
  return source == _achievementsSource && subtype == 'unlock_v1';
}

bool isDailyCompleteNotification({
  required String source,
  String? subtype,
}) {
  return source == _dailyGoalsSource && subtype == 'complete_v1';
}

bool isLegacyOfferNotification({
  required String source,
  String? subtype,
}) {
  return source == _legacySource && subtype == 'offer_v1';
}

bool isLegacyLeaderPressureNotification({
  required String source,
  String? subtype,
}) {
  return source == _legacySource && subtype == 'pressure_v1';
}

bool isLegacyLeaderChaseNotification({
  required String source,
  String? subtype,
}) {
  return source == _legacySource && subtype == 'chase_v1';
}
