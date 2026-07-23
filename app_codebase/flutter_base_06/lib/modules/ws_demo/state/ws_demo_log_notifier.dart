import 'package:flutter_riverpod/flutter_riverpod.dart';

class WsDemoLogNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => const [];

  void append(String line) {
    state = [line, ...state].take(20).toList();
  }

  void clear() => state = const [];
}

final wsDemoLogProvider =
    NotifierProvider<WsDemoLogNotifier, List<String>>(WsDemoLogNotifier.new);
