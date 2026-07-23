import 'response_types.dart';

class NavigateButton {
  const NavigateButton({
    required this.label,
    this.screen,
    this.toPath,
  });

  final String label;
  final String? screen;
  final String? toPath;

  factory NavigateButton.fromJson(Map<String, dynamic> json) {
    final screen = json['screen']?.toString().trim();
    final toPath = json['to_path']?.toString().trim();
    return NavigateButton(
      label: json['label']?.toString() ?? '',
      screen: screen != null && screen.isNotEmpty ? screen : null,
      toPath: toPath != null && toPath.isNotEmpty ? toPath : null,
    );
  }
}

class ReplyOption {
  const ReplyOption({
    required this.key,
    required this.label,
  });

  final String key;
  final String label;

  factory ReplyOption.fromJson(Map<String, dynamic> json) {
    return ReplyOption(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
    );
  }
}

sealed class NotificationResponseConfig {
  const NotificationResponseConfig();

  factory NotificationResponseConfig.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString().trim().toLowerCase();
    if (type == NotificationResponseTypes.navigate) {
      return NavigateResponseConfig.fromJson(json);
    }
    if (type == NotificationResponseTypes.reply) {
      return ReplyResponseConfig.fromJson(json);
    }
    throw FormatException('Unknown notification response type: $type');
  }

  static NotificationResponseConfig? fromMessageData(Map<String, dynamic> data) {
    final response = data['response'];
    if (response is! Map) {
      return null;
    }
    try {
      return NotificationResponseConfig.fromJson(
        Map<String, dynamic>.from(response),
      );
    } catch (_) {
      return null;
    }
  }
}

class NavigateResponseConfig extends NotificationResponseConfig {
  const NavigateResponseConfig({
    required this.buttons,
    this.markReadOnAction = true,
  });

  final List<NavigateButton> buttons;
  final bool markReadOnAction;

  factory NavigateResponseConfig.fromJson(Map<String, dynamic> json) {
    final rawButtons = json['buttons'];
    final buttons = rawButtons is List
        ? rawButtons
            .whereType<Map>()
            .map((item) => NavigateButton.fromJson(Map<String, dynamic>.from(item)))
            .where((button) => button.label.isNotEmpty)
            .take(kMaxNavigateButtons)
            .toList()
        : <NavigateButton>[];
    return NavigateResponseConfig(
      buttons: buttons,
      markReadOnAction: json['mark_read_on_action'] != false,
    );
  }
}

class ReplyResponseConfig extends NotificationResponseConfig {
  const ReplyResponseConfig({
    required this.options,
    this.markReadOnSuccess = true,
  });

  final List<ReplyOption> options;
  final bool markReadOnSuccess;

  factory ReplyResponseConfig.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions
            .whereType<Map>()
            .map((item) => ReplyOption.fromJson(Map<String, dynamic>.from(item)))
            .where((option) => option.key.isNotEmpty && option.label.isNotEmpty)
            .take(kMaxReplyOptions)
            .toList()
        : <ReplyOption>[];
    return ReplyResponseConfig(
      options: options,
      markReadOnSuccess: json['mark_read_on_success'] != false,
    );
  }
}
