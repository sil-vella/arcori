/// Optional type/subtype action packs (events, quickStart variants, …).
///
/// Practice has no subtype and registers no pack.
library;

import 'action_pack.dart';

class TypeSubtypePackRegistry {
  final Map<String, MatchActionPack> _packs = {};

  static String key(String code, String? subtype) {
    final c = code.trim();
    final s = subtype?.trim();
    if (s == null || s.isEmpty) return c;
    return '$c:$s';
  }

  void register(String code, {String? subtype, required MatchActionPack pack}) {
    _packs[key(code, subtype)] = pack;
  }

  MatchActionPack? packFor(Map<String, dynamic> matchType) {
    final code = matchType['code']?.toString() ?? '';
    if (code.isEmpty) return null;
    final subtype = matchType['subtype']?.toString();
    return _packs[key(code, subtype)];
  }

  void clear() => _packs.clear();
}

final typeSubtypePackRegistry = TypeSubtypePackRegistry();
