import 'package:flutter_test/flutter_test.dart';

import 'package:arcori/modules/avari/avari_models.dart';
import 'package:arcori/modules/avari/circulating_browse.dart';

AvariInventoryItem _item({
  required String id,
  required String name,
  double mastery = 10,
  int? reach,
  String? theme,
  String? series,
}) {
  return AvariInventoryItem(
    designId: id,
    displayName: name,
    masteryPoints: mastery,
    mintReach: reach,
    theme: theme,
    seriesKey: series,
  );
}

void main() {
  final access = [
    _item(
      id: 'a',
      name: 'Amber',
      mastery: 20,
      reach: 100,
      theme: 'Flora',
      series: 'Genesis',
    ),
    _item(
      id: 'b',
      name: 'Bronze',
      mastery: 80,
      reach: 100,
      theme: 'Metal',
      series: 'Genesis',
    ),
    _item(
      id: 'c',
      name: 'Gone',
      mastery: 0,
      theme: 'Flora',
      series: 'Genesis',
    ),
  ];

  test('theme filter drops zero mastery and ignores the search box', () {
    final items = filterCirculating(
      access,
      theme: 'Flora',
      seriesKey: null,
      sort: CirculatingSort.mastery,
    );
    expect(items.map((item) => item.designId), ['a']);
  });

  test('search matches the whole collection, not the selected theme', () {
    final items = searchCirculating(
      access,
      query: 'bronze',
      sort: CirculatingSort.mastery,
    );
    expect(items.map((item) => item.designId), ['b']);
  });

  test('near mint ranks the fuller reach first', () {
    final items = filterCirculating(
      access,
      theme: null,
      seriesKey: 'Genesis',
      sort: CirculatingSort.nearMint,
    );
    expect(items.map((item) => item.designId), ['b', 'a']);
  });

  test('facets are the mastered themes only', () {
    expect(
      circulatingFacet(access, (item) => item.theme),
      ['Flora', 'Metal'],
    );
  });

  test('canisters hold 100 in browse order, with a progress canister last', () {
    final mastered = [
      for (var i = 0; i < 250; i++)
        _item(id: 'd$i', name: 'Design $i', mastery: (250 - i).toDouble()),
    ];
    final canisters = packCirculatingCanisters(mastered);
    expect(canisters, hasLength(3));
    expect(canisters[0].filling, isFalse);
    expect(canisters[0].items, hasLength(100));
    expect(canisters[0].items.first.designId, 'd0');
    expect(canisters[1].items.first.designId, 'd100');
    expect(canisters[2].filling, isTrue);
    expect(canisters[2].filled, 50);
    expect(canisters[2].items.first.designId, 'd200');
  });

  test('an empty list and an exact hundred still leave one canister to fill', () {
    expect(packCirculatingCanisters(<AvariInventoryItem>[]).single.filling, isTrue);
    expect(packCirculatingCanisters(<AvariInventoryItem>[]).single.filled, 0);

    final hundred = [
      for (var i = 0; i < 100; i++) _item(id: 'h$i', name: 'Held $i'),
    ];
    final canisters = packCirculatingCanisters(hundred);
    expect(canisters, hasLength(2));
    expect(canisters[0].items, hasLength(100));
    expect(canisters[1].filling, isTrue);
    expect(canisters[1].filled, 0);
  });

  test('zero mastery is dropped before a canister is packed', () {
    final items = filterCirculating(
      access,
      theme: null,
      seriesKey: null,
      sort: CirculatingSort.mastery,
    );
    final canisters = packCirculatingCanisters(items);
    expect(canisters, hasLength(1));
    expect(canisters.single.filling, isTrue);
    expect(
      canisters.single.items.map((item) => item.designId),
      ['b', 'a'],
    );
  });
}
