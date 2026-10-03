import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:arcori/core/intro/intro_video_screen.dart';

void main() {
  late VideoPlayerPlatform previousPlatform;

  setUp(() {
    previousPlatform = VideoPlayerPlatform.instance;
  });

  tearDown(() {
    VideoPlayerPlatform.instance = previousPlatform;
  });

  testWidgets('intro video plays and finishes', (tester) async {
    VideoPlayerPlatform.instance = _FakeIntroVideoPlatform();
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: IntroVideoScreen(onFinished: () => finished = true),
      ),
    );

    var sawPlayer = false;
    for (var i = 0; i < 8; i++) {
      await tester.pump();
      if (find.byType(VideoPlayer).evaluate().isNotEmpty) {
        sawPlayer = true;
      }
    }
    expect(find.byType(IntroVideoScreen), findsOneWidget);
    expect(sawPlayer, isTrue);
    expect(finished, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('intro video closes when playback fails', (tester) async {
    VideoPlayerPlatform.instance = _FakeIntroVideoPlatform(failOnEvent: true);
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        home: IntroVideoScreen(onFinished: () => finished = true),
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(finished, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeIntroVideoPlatform extends VideoPlayerPlatform {
  _FakeIntroVideoPlatform({this.failOnEvent = false});

  final bool failOnEvent;
  final Map<int, StreamController<VideoEvent>> _events = {};
  var _nextId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final playerId = _nextId++;
    final controller = StreamController<VideoEvent>();
    _events[playerId] = controller;
    if (failOnEvent) {
      controller.addError(
        PlatformException(code: 'asset', message: 'intro missing'),
      );
    } else {
      controller.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(milliseconds: 400),
          size: const Size(720, 1280),
        ),
      );
    }
    return playerId;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    return _events[playerId]!.stream;
  }

  @override
  Future<void> play(int playerId) async {
    _events[playerId]?.add(VideoEvent(eventType: VideoEventType.completed));
  }

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Widget buildView(int playerId) {
    return const SizedBox.shrink();
  }

  @override
  Widget buildViewWithOptions(VideoViewOptions options) {
    return const SizedBox.shrink();
  }
}
