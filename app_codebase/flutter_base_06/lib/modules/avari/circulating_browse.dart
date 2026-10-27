import 'avari_models.dart';
import 'widgets/arcori_container_bank.dart';

/// How the player's circulating Arcori list is ordered.
enum CirculatingSort { mastery, name, nearMint }

/// Circulating access the player still holds (mastery above 0).
List<AvariInventoryItem> circulatingMastered(Iterable<AvariInventoryItem> access) {
  return [
    for (final item in access)
      if (item.masteryPoints > 0) item,
  ];
}

/// Theme and series, then sort. Null filters keep the mastered set.
/// Search is separate: it does not narrow or widen this list.
List<AvariInventoryItem> filterCirculating(
  Iterable<AvariInventoryItem> access, {
  String? theme,
  String? seriesKey,
  required CirculatingSort sort,
}) {
  final items = circulatingMastered(access).where((item) {
    if (theme != null && (item.theme ?? '') != theme) return false;
    if (seriesKey != null && (item.seriesKey ?? '') != seriesKey) return false;
    return true;
  }).toList();
  _sortCirculating(items, sort);
  return items;
}

/// Name and design id across the whole circulating set, then sort.
/// Theme and series selections do not apply.
List<AvariInventoryItem> searchCirculating(
  Iterable<AvariInventoryItem> access, {
  required String query,
  required CirculatingSort sort,
}) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) {
    return filterCirculating(access, sort: sort);
  }
  final items = circulatingMastered(access).where((item) {
    return item.displayName.toLowerCase().contains(needle) ||
        item.designId.toLowerCase().contains(needle);
  }).toList();
  _sortCirculating(items, sort);
  return items;
}

void _sortCirculating(List<AvariInventoryItem> items, CirculatingSort sort) {
  int byName(AvariInventoryItem a, AvariInventoryItem b) {
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  switch (sort) {
    case CirculatingSort.name:
      items.sort(byName);
    case CirculatingSort.mastery:
      items.sort((a, b) {
        final points = b.masteryPoints.compareTo(a.masteryPoints);
        return points != 0 ? points : byName(a, b);
      });
    case CirculatingSort.nearMint:
      items.sort((a, b) {
        final ratio = _mintRatio(b).compareTo(_mintRatio(a));
        return ratio != 0 ? ratio : byName(a, b);
      });
  }
}

/// One sealed canister of circulating Arcori, in the current browse order.
class CirculatingCanister {
  const CirculatingCanister({
    required this.index,
    required this.items,
    required this.filling,
  });

  /// Zero-based slot. The last slot is the one still filling.
  final int index;

  /// Designs packed into this canister. At most [ArcoriContainerBank.perContainer].
  final List<AvariInventoryItem> items;

  /// True for the progress canister. It is always the last slot.
  final bool filling;

  int get filled => items.length;
}

/// Split an already filtered and sorted list into canisters of 100.
///
/// The first canister holds the first 100 designs. The last canister is always
/// the one still filling, including when the list is empty or an exact hundred.
List<CirculatingCanister> packCirculatingCanisters(
  List<AvariInventoryItem> items,
) {
  final per = ArcoriContainerBank.perContainer;
  if (items.isEmpty) {
    return const [
      CirculatingCanister(
        index: 0,
        items: <AvariInventoryItem>[],
        filling: true,
      ),
    ];
  }
  final full = items.length ~/ per;
  final canisters = <CirculatingCanister>[
    for (var i = 0; i < full; i++)
      CirculatingCanister(
        index: i,
        items: items.sublist(i * per, (i + 1) * per),
        filling: false,
      ),
  ];
  canisters.add(
    CirculatingCanister(
      index: full,
      items: items.sublist(full * per),
      filling: true,
    ),
  );
  return canisters;
}

double _mintRatio(AvariInventoryItem item) {
  final reach = item.masteryCap ?? item.mintReach;
  if (reach == null || reach <= 0) return -1;
  return item.masteryPoints / reach;
}

/// Distinct non-empty values, alphabetical.
List<String> circulatingFacet(
  Iterable<AvariInventoryItem> access,
  String? Function(AvariInventoryItem item) read,
) {
  final values = <String>{};
  for (final item in circulatingMastered(access)) {
    final value = read(item)?.trim() ?? '';
    if (value.isNotEmpty) values.add(value);
  }
  final list = values.toList()..sort();
  return list;
}
