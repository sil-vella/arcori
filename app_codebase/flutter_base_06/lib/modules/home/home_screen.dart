import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_bar/app_bar_registrar.dart';
import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/navigation/app_navigation.dart';
import '../../core/navigation/app_paths.dart';
import '../../core/state/auth/auth_providers.dart';
import '../avari/avari_notifier.dart';

const String _kDebugFinalizeAsset =
    'assets/debug/match_finalize_sample.json';
const String _kSelfPlaceholder = '__SELF__';

/// Body for `/` — chrome (drawer, app bar) lives in [AppShell].
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _counter = 0;
  bool _finalizeBusy = false;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  Future<void> _debugFinalizeFromAsset() async {
    if (_finalizeBusy) return;
    final auth = ref.read(authProvider);
    final token = auth.accessToken?.trim() ?? '';
    final userId = auth.userId?.trim() ?? '';
    if (token.isEmpty || userId.isEmpty) {
      _snack('Sign in first.');
      return;
    }

    setState(() => _finalizeBusy = true);
    try {
      final raw = await rootBundle.loadString(_kDebugFinalizeAsset);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _snack('Invalid finalize fixture JSON.');
        return;
      }
      final j = Map<String, dynamic>.from(decoded);
      final unique = j['uniqueMatchId'] == true;
      var matchId = j['matchId']?.toString().trim() ?? '';
      if (matchId.isEmpty) {
        _snack('Fixture missing matchId.');
        return;
      }
      if (unique) {
        matchId = '$matchId-${DateTime.now().millisecondsSinceEpoch}';
      }

      final designRaw = j['designIds'];
      final designIds = designRaw is List
          ? designRaw.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
          : <String>[];

      Map<String, int>? flipsByDesign;
      final flipsRaw = j['flipsByDesign'];
      if (flipsRaw is Map) {
        flipsByDesign = {
          for (final e in flipsRaw.entries)
            e.key.toString(): e.value is int
                ? e.value as int
                : int.tryParse('${e.value}') ?? 0,
        };
      }

      Map<String, dynamic>? result;
      final resultRaw = j['result'];
      if (resultRaw is Map) {
        result = _injectSelfIntoResult(
          Map<String, dynamic>.from(resultRaw),
          userId,
        );
      }

      final flips = j['flips'] is int
          ? j['flips'] as int
          : int.tryParse('${j['flips'] ?? ''}') ?? 0;
      final practice = j['practice'] == true;
      final matchType = j['matchType']?.toString().trim().isNotEmpty == true
          ? j['matchType'].toString().trim()
          : 'quickStart';
      final played = j['playedDesignId']?.toString().trim();
      final eventId = j['eventId']?.toString().trim();

      final outcome = await ref.read(avariApiClientProvider).finalizeMatch(
            accessToken: token,
            matchId: matchId,
            matchType: matchType,
            practice: practice,
            designIds: designIds,
            flips: flips,
            playedDesignId:
                (played != null && played.isNotEmpty) ? played : null,
            eventId: (eventId != null && eventId.isNotEmpty) ? eventId : null,
            flipsByDesign: flipsByDesign,
            result: result,
          );

      if (!mounted) return;
      if (outcome.isNetworkError) {
        _snack('Finalize network error.');
        return;
      }
      if (!outcome.isSuccess || outcome.data == null) {
        final code = outcome.error?.code ?? 'error';
        _snack('Finalize failed: $code');
        return;
      }
      final data = outcome.data!;
      _snack(
        'Finalize ${data.applied ? 'applied' : 'skipped'} '
        '(${data.reason}) matchId=$matchId',
      );
    } catch (e) {
      if (mounted) {
        _snack('Finalize error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _finalizeBusy = false);
      }
    }
  }

  Map<String, dynamic> _injectSelfIntoResult(
    Map<String, dynamic> result,
    String userId,
  ) {
    final out = Map<String, dynamic>.from(result);
    final winnersRaw = out['winnerUserIds'];
    if (winnersRaw is List) {
      out['winnerUserIds'] = [
        for (final w in winnersRaw)
          w.toString() == _kSelfPlaceholder ? userId : w.toString(),
      ];
    }
    final scoresRaw = out['finalScores'];
    if (scoresRaw is Map) {
      final scores = <String, dynamic>{};
      for (final e in scoresRaw.entries) {
        final key = e.key.toString() == _kSelfPlaceholder
            ? userId
            : e.key.toString();
        scores[key] = e.value;
      }
      out['finalScores'] = scores;
    }
    return out;
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBarRegistrar(
      items: const [
        AppBarTitle(text: 'Home', icon: Icons.home),
      ],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _incrementCounter,
              icon: const Icon(Icons.add),
              label: const Text('Increment'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Nav.push(context, AppPaths.velora),
              child: const Text('Velora'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () => Nav.push(context, AppPaths.sample),
              child: const Text('Open sample module'),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _finalizeBusy ? null : _debugFinalizeFromAsset,
              icon: _finalizeBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bug_report),
              label: Text(
                _finalizeBusy ? 'Finalizing…' : 'Debug match finalize',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
