/// Launch lands from the world bible and `01_regions.json`.
/// Ties are political and cultural. They do not bar travel or collecting.
class VeloraRegion {
  const VeloraRegion({
    required this.code,
    required this.name,
    required this.asset,
    required this.identity,
    required this.lore,
    required this.alliance,
    required this.standings,
    required this.places,
  });

  final String code;
  final String name;
  final String asset;
  final String identity;
  final String lore;
  final String alliance;
  final List<VeloraStanding> standings;
  final List<VeloraPlace> places;
}

class VeloraStanding {
  const VeloraStanding({
    required this.otherCode,
    required this.label,
    required this.reason,
  });

  final String otherCode;
  final String label;
  final String reason;
}

class VeloraPlace {
  const VeloraPlace({required this.name, required this.asset});

  final String name;
  final String asset;
}

const String _root = 'assets/images/velora/regions';

const List<VeloraRegion> veloraRegions = [
  VeloraRegion(
    code: 'ASH',
    name: 'Ashdrift Hill',
    asset: '$_root/ashdrift-hill/region.webp',
    identity:
        'Silence, obscured memories, psychological mystery, forgotten ruins',
    lore:
        'Ash falls endlessly across Ashdrift Hill, although no fire or volcano has ever been found. Roads disappear beneath pale drifts, abandoned structures emerge without warning, and distant figures sometimes appear through the grey before vanishing again.\n\n'
        'The people of Ashdrift believe the falling ash is the remains of memories that Velora could not preserve. Others claim something beneath the hill is still burning — but no Chronicle confirms what it might be.',
    alliance:
        'The Veiled Accord, with Moonwake Bay. They study lost memories and places that appear only briefly.',
    standings: [
      VeloraStanding(
        otherCode: 'EVG',
        label: 'Hostility',
        reason:
            'Everlight believes something beneath Ashdrift threatens Velora. Ashdrift considers Everlight’s attempted interventions an invasion.',
      ),
      VeloraStanding(
        otherCode: 'AMB',
        label: 'Neutral',
        reason:
            'Both preserve the past differently: Ashdrift lets memories fall and fade; Amberwild traps them in amber. They remain curious but distant.',
      ),
      VeloraStanding(
        otherCode: 'LFR',
        label: 'Neutral',
        reason:
            'Their harsh climates create mutual understanding, but neither region entirely trusts the other’s strange disappearances and recoveries.',
      ),
      VeloraStanding(
        otherCode: 'MWB',
        label: 'Affinity',
        reason:
            'Both study places and memories that appear only briefly. Their pathfinders regularly exchange discoveries.',
      ),
    ],
    places: [
      VeloraPlace(
        name: 'Hospital',
        asset: '$_root/ashdrift-hill/hospital.webp',
      ),
      VeloraPlace(
        name: 'School',
        asset: '$_root/ashdrift-hill/school.webp',
      ),
      VeloraPlace(
        name: 'Walled Alley',
        asset: '$_root/ashdrift-hill/walled-alley.webp',
      ),
    ],
  ),
  VeloraRegion(
    code: 'EVG',
    name: 'Everlight Grove',
    asset: '$_root/everlight-grove/region.webp',
    identity:
        'Teamwork, transformation, colourful energy, ancient guardians',
    lore:
        'Everlight Grove is a bright, energetic land where enormous trees grow around ancient pillars of coloured light. Each pillar shines differently, but when danger threatens the Grove, their separate colours converge into a single radiant force.\n\n'
        'Old carvings depict groups of guardians standing beside colossal animal-shaped figures. Whether these were creatures, machines or symbolic protectors has been forgotten. The light continues to choose new defenders whenever the Grove needs them.',
    alliance:
        'The Living Pact, with Amberwild. They defend living wilderness and ancient forces.',
    standings: [
      VeloraStanding(
        otherCode: 'ASH',
        label: 'Hostility',
        reason:
            'Everlight believes something beneath Ashdrift threatens Velora. Ashdrift considers Everlight’s attempted interventions an invasion.',
      ),
      VeloraStanding(
        otherCode: 'MWB',
        label: 'Tension',
        reason:
            'Everlight wants dangerous discoveries secured. Moonwake believes forgotten places must remain open to exploration.',
      ),
      VeloraStanding(
        otherCode: 'LFR',
        label: 'Favourable',
        reason:
            'Everlight repeatedly assists Little Frost after its inexplicable disasters. Little Frost appreciates the help but mocks Everlight’s ceremony.',
      ),
      VeloraStanding(
        otherCode: 'AMB',
        label: 'Affinity',
        reason:
            'The Grove’s guardians protect Amberwild’s living wilderness, while Amberwild provides ancient knowledge and materials.',
      ),
    ],
    places: [
      VeloraPlace(
        name: 'Weathered City',
        asset: '$_root/everlight-grove/weathered-city.webp',
      ),
      VeloraPlace(
        name: 'Mountain Command Center',
        asset: '$_root/everlight-grove/mountain-command-center.webp',
      ),
      VeloraPlace(
        name: 'Ocean Guardian Sanctuary',
        asset: '$_root/everlight-grove/ocean-guardian-sanctuary.webp',
      ),
    ],
  ),
  VeloraRegion(
    code: 'LFR',
    name: 'Little Frost',
    asset: '$_root/little-frost/region.webp',
    identity: 'Snowy small-town life, absurdity, dark comedy, recurring chaos',
    lore:
        'Little Frost is a remote settlement surrounded by snowy mountains and seemingly trapped in permanent winter. Its colourful houses, modest streets and cheerful residents make it appear peaceful — until something strange inevitably happens.\n\n'
        'Monsters, visitors, unexplained disasters and ridiculous disputes are treated as normal inconveniences. Buildings may be destroyed one day and stand untouched the next morning. No one agrees whether the town heals itself or simply refuses to remember what happened.',
    alliance:
        'Independent. Friendly with Everlight Grove and Moonwake Bay, and a member of neither alliance.',
    standings: [
      VeloraStanding(
        otherCode: 'AMB',
        label: 'Tension',
        reason:
            'Amberwild considers Little Frost careless and destructive. Little Frost sees Amberwild’s preservation customs as overly serious and restrictive.',
      ),
      VeloraStanding(
        otherCode: 'ASH',
        label: 'Neutral',
        reason:
            'Their harsh climates create mutual understanding, but neither region entirely trusts the other’s strange disappearances and recoveries.',
      ),
      VeloraStanding(
        otherCode: 'EVG',
        label: 'Favourable',
        reason:
            'Everlight repeatedly assists Little Frost after its inexplicable disasters. Little Frost appreciates the help but mocks Everlight’s ceremony.',
      ),
      VeloraStanding(
        otherCode: 'MWB',
        label: 'Favourable',
        reason:
            'Traders cross the frozen routes between them. Both cultures are comfortable living beside unexplained phenomena.',
      ),
    ],
    places: [
      VeloraPlace(
        name: 'Elementary School',
        asset: '$_root/little-frost/elementary-school.webp',
      ),
      VeloraPlace(
        name: 'Deserted School Halls',
        asset: '$_root/little-frost/deserted-school-halls.webp',
      ),
      VeloraPlace(
        name: 'Snowy Forest',
        asset: '$_root/little-frost/snowy-forest.webp',
      ),
    ],
  ),
  VeloraRegion(
    code: 'MWB',
    name: 'Moonwake Bay',
    asset: '$_root/moonwake-bay/region.webp',
    identity: 'Ocean mystery, moonlit exploration, lost places, changing tides',
    lore:
        'Moonwake Bay lies along a luminous coast where the sea glows beneath the moon. When the tide retreats, it reveals pathways, Arcori markings and fragments of structures that do not appear on any map.\n\n'
        'Sailors believe the moon pulls more than water from the bay — it draws forgotten places close to Velora. Some ruins remain exposed for minutes; others endure for generations. Those who follow the lights beneath the waves do not always return to the same shore.',
    alliance:
        'The Veiled Accord, with Ashdrift Hill. They study lost memories and places that appear only briefly.',
    standings: [
      VeloraStanding(
        otherCode: 'EVG',
        label: 'Tension',
        reason:
            'Everlight wants dangerous discoveries secured. Moonwake believes forgotten places must remain open to exploration.',
      ),
      VeloraStanding(
        otherCode: 'AMB',
        label: 'Tension',
        reason:
            'They dispute relics uncovered where the changing shoreline meets Amberwild territory.',
      ),
      VeloraStanding(
        otherCode: 'LFR',
        label: 'Favourable',
        reason:
            'Traders cross the frozen routes between them. Both cultures are comfortable living beside unexplained phenomena.',
      ),
      VeloraStanding(
        otherCode: 'ASH',
        label: 'Affinity',
        reason:
            'Both study places and memories that appear only briefly. Their pathfinders regularly exchange discoveries.',
      ),
    ],
    places: [
      VeloraPlace(
        name: 'Drowned Harbor',
        asset: '$_root/moonwake-bay/drowned-harbor.webp',
      ),
      VeloraPlace(
        name: 'Tideglass Caves',
        asset: '$_root/moonwake-bay/tideglass-caves.webp',
      ),
      VeloraPlace(
        name: 'Tidal Observatory',
        asset: '$_root/moonwake-bay/tidal-observatory.webp',
      ),
    ],
  ),
  VeloraRegion(
    code: 'AMB',
    name: 'Amberwild',
    asset: '$_root/amberwild/region.webp',
    identity:
        'Wilderness, ancient life, preserved moments, exploration, awakening',
    lore:
        'Amberwild is a vast golden wilderness of sunlit grasslands, dense forests and towering amber formations. Within the amber rest shapes resembling extinct creatures, unfamiliar objects and moments seemingly frozen in time.\n\n'
        'The land feels ancient, yet new discoveries appear after every great storm. Some believe Amberwild preserves memories before they can fade. Others warn that the amber is not preserving its inhabitants — it is waiting to release them.',
    alliance:
        'The Living Pact, with Everlight Grove. They defend living wilderness and ancient forces.',
    standings: [
      VeloraStanding(
        otherCode: 'MWB',
        label: 'Tension',
        reason:
            'They dispute relics uncovered where the changing shoreline meets Amberwild territory.',
      ),
      VeloraStanding(
        otherCode: 'LFR',
        label: 'Tension',
        reason:
            'Amberwild considers Little Frost careless and destructive. Little Frost sees Amberwild’s preservation customs as overly serious and restrictive.',
      ),
      VeloraStanding(
        otherCode: 'ASH',
        label: 'Neutral',
        reason:
            'Both preserve the past differently: Ashdrift lets memories fall and fade; Amberwild traps them in amber. They remain curious but distant.',
      ),
      VeloraStanding(
        otherCode: 'EVG',
        label: 'Affinity',
        reason:
            'The Grove’s guardians protect Amberwild’s living wilderness, while Amberwild provides ancient knowledge and materials.',
      ),
    ],
    places: [
      VeloraPlace(
        name: 'Stillstorm Forest',
        asset: '$_root/amberwild/stillstorm-forest.webp',
      ),
      VeloraPlace(
        name: 'Stormglass Basin',
        asset: '$_root/amberwild/stormglass-basin.webp',
      ),
      VeloraPlace(
        name: 'Amberfall Ravine',
        asset: '$_root/amberwild/amberfall-ravine.webp',
      ),
    ],
  ),
  VeloraRegion(
    code: 'RBY',
    name: 'Realm Beyond',
    asset: '$_root/realm-beyond/region.webp',
    identity:
        'Beyond the veil. Not a Velora land, and outside every alliance',
    lore:
        'The Realm Beyond is not a land of Velora. Chronicles say the veil between them was once so thin that every laugh, hope and act of wonder echoed freely — remembered only as The Bright Time. Then the echoes faded. The Realm Beyond grew heavier, and the First Hands found themselves unable to return.\n\n'
        'What still crosses the veil does so without treaty or feud. The Realm Beyond holds no affinities and no hostilities. It is the unanswered elsewhere every generation inherits.',
    alliance:
        'None. It joins no alliance and holds no affinities or hostilities.',
    standings: [],
    places: [],
  ),
];

VeloraRegion? veloraRegionByCode(String code) {
  final key = code.trim().toUpperCase();
  for (final region in veloraRegions) {
    if (region.code == key) return region;
  }
  return null;
}

String veloraRegionName(String code) {
  return veloraRegionByCode(code)?.name ?? code;
}
