import 'package:flutter/material.dart';

import '../../utils/dev_logger.dart';

const bool LOGGING_SWITCH = true; // ignore: constant_identifier_names

/// Full-screen intro with bouncing brand text; calls [onFinished] when done.
class IntroLottieScreen extends StatefulWidget {
  const IntroLottieScreen({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<IntroLottieScreen> createState() => _IntroLottieScreenState();
}

class _IntroLottieScreenState extends State<IntroLottieScreen>
    with SingleTickerProviderStateMixin {
  static const _introText = 'WF Brand Lottie';
  static const _bounceCount = 5;
  static const _introDuration = Duration(milliseconds: 3500);
  static const _bounceHeight = 90.0;

  late final AnimationController _controller;
  late final Animation<double> _bounceY;

  @override
  void initState() {
    super.initState();
    if (LOGGING_SWITCH) {
      customlog('IntroLottieScreen: init, duration=${_introDuration.inMilliseconds}ms');
    }
    _controller = AnimationController(vsync: this, duration: _introDuration);
    _bounceY = _buildBounceAnimation();
    _controller.forward().whenComplete(_finishIntro);
    if (LOGGING_SWITCH) {
      customlog('IntroLottieScreen: bounce animation started');
    }
  }

  Animation<double> _buildBounceAnimation() {
    final items = <TweenSequenceItem<double>>[];
    for (var bounce = 0; bounce < _bounceCount; bounce++) {
      items
        ..add(
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: -_bounceHeight)
                .chain(CurveTween(curve: Curves.easeOut)),
            weight: 1,
          ),
        )
        ..add(
          TweenSequenceItem(
            tween: Tween<double>(begin: -_bounceHeight, end: 0)
                .chain(CurveTween(curve: Curves.bounceOut)),
            weight: 1,
          ),
        );
    }
    return TweenSequence<double>(items).animate(_controller);
  }

  void _finishIntro() {
    if (!mounted) {
      return;
    }
    if (LOGGING_SWITCH) {
      customlog('IntroLottieScreen: animation complete, closing intro');
    }
    widget.onFinished();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SizedBox.expand(
        child: Center(
          child: AnimatedBuilder(
            animation: _bounceY,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _bounceY.value),
              child: child,
            ),
            child: const Text(
              _introText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
