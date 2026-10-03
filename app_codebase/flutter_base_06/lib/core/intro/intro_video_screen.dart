import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../utils/dev_logger.dart';
import '../config/app_config.dart';
import '../theme/theme.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Full-screen intro video; calls [onFinished] when playback ends or fails.
class IntroVideoScreen extends StatefulWidget {
  const IntroVideoScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IntroVideoScreen> createState() => _IntroVideoScreenState();
}

class _IntroVideoScreenState extends State<IntroVideoScreen> {
  late final VideoPlayerController _controller;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(AppConfig.introVideoAsset);
    if (LOGGING_SWITCH) {
      customlog('IntroVideoScreen: init asset=${AppConfig.introVideoAsset}');
    }
    _start();
  }

  Future<void> _start() async {
    try {
      await _controller.initialize();
      if (!mounted || _finished) {
        return;
      }
      _controller.addListener(_onPlaybackTick);
      setState(() {});
      await _controller.setLooping(false);
      if (kIsWeb) {
        await _controller.setVolume(0);
      }
      await _controller.play();
      if (LOGGING_SWITCH) {
        customlog(
          'IntroVideoScreen: playback started '
          'duration=${_controller.value.duration.inMilliseconds}ms',
        );
      }
      _onPlaybackTick();
    } catch (error) {
      if (LOGGING_SWITCH) {
        customlog('IntroVideoScreen: playback failed error=$error');
      }
      _finish();
    }
  }

  void _onPlaybackTick() {
    final value = _controller.value;
    if (value.hasError) {
      if (LOGGING_SWITCH) {
        customlog(
          'IntroVideoScreen: player error ${value.errorDescription}',
        );
      }
      _finish();
      return;
    }
    if (value.isCompleted) {
      _finish();
    }
  }

  void _finish() {
    if (_finished) {
      return;
    }
    _finished = true;
    if (LOGGING_SWITCH) {
      customlog('IntroVideoScreen: intro complete, closing');
    }
    if (!mounted) {
      return;
    }
    widget.onFinished();
  }

  @override
  void dispose() {
    _finished = true;
    _controller.removeListener(_onPlaybackTick);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.backgroundDark,
      child: SizedBox.expand(child: _player()),
    );
  }

  Widget _player() {
    final value = _controller.value;
    if (!value.isInitialized) {
      return const SizedBox.shrink();
    }
    final size = value.size;
    if (size.isEmpty) {
      return VideoPlayer(_controller);
    }
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(_controller),
      ),
    );
  }
}
