import '../models/garden_models.dart';

/// Bundled peer-to-peer homestead field guides for all 9 Tanzania starter crops.
/// Designed as a starting reference that grows with the farmer's own notes and
/// saved Mentor advice over time (works 100% offline).
class CropFieldGuide {
  const CropFieldGuide({
    required this.profileId,
    required this.commonName,
    required this.localNameSw,
    required this.family,
    required this.daysToHarvestMin,
    required this.daysToHarvestMax,
    required this.wateringGuide,
    required this.spacingGuide,
    required this.seasonAndWeatherNotes,
    required this.whatToLookFor,
    required this.stageCareTips,
    required this.nutritionNotes,
  });

  final String profileId;
  final String commonName;
  final String localNameSw;
  final String family;
  final int daysToHarvestMin;
  final int daysToHarvestMax;
  final String wateringGuide;
  final String spacingGuide;
  final String seasonAndWeatherNotes;
  final List<String> whatToLookFor;
  final List<String> stageCareTips;
  final String nutritionNotes;
}

const Map<String, CropFieldGuide> kCropFieldLibrary = {
  'tz_tomato': CropFieldGuide(
    profileId: 'tz_tomato',
    commonName: 'Tomato',
    localNameSw: 'Nyanya',
    family: 'Solanaceae',
    daysToHarvestMin: 70,
    daysToHarvestMax: 85,
    wateringGuide:
        'Water slowly at the soil base before 09:00 AM. Keep leaves dry to prevent fungal blight. Check soil 5 cm deep before watering and skip outdoor beds after heavy rain (>12 mm).',
    spacingGuide:
        '60 cm between plants × 90–100 cm between rows. Stake before flowering to keep stems and fruit off wet soil.',
    seasonAndWeatherNotes:
        'Cool/dry season (June–August): lower blight pressure, watch for spider mites and water steadily to avoid blossom end rot. Rainy season: prioritize airflow, staking, and dry grass mulch to stop soil splash.',
    whatToLookFor: [
      'Lower-leaf yellowing on bottom 1–2 shaded leaves: normal aging—snip cleanly, do not panic-spray.',
      'Dark water-soaked leaf spots spreading fast in cool/wet weather: early sign of Late Blight.',
      'Sunken black patch at fruit bottom: Blossom End Rot from uneven watering or low calcium uptake.',
      'Leaf undersides twice weekly for whiteflies, aphids, and fruit-boring caterpillars.',
    ],
    stageCareTips: [
      'Nursery / Week 1–2: Keep nursery shaded during midday heat; harden off seedlings 5 days before transplanting.',
      'Vegetative: Apply clean dry grass mulch 3 cm away from the stem collar and install stakes early.',
      'Flowering: Keep soil moisture consistent—dry-to-wet swings cause flower drop.',
      'Fruiting & Harvest: Leave upper canopy leaves to shade fruit from sunscald; pick at breaker or red stage.',
    ],
    nutritionNotes:
        'Water soil before any side-dressing and keep granules at least 5 cm from the stem. Typical Tanzania schedule uses basal DAP at transplant, CAN/Urea top-dressing in vegetative growth, and NPK 17:17:17 + Calcium-Boron support at flowering/fruiting. Follow verified label rates.',
  ),
  'tz_cucumber': CropFieldGuide(
    profileId: 'tz_cucumber',
    commonName: 'Cucumber',
    localNameSw: 'Tango',
    family: 'Cucurbitaceae',
    daysToHarvestMin: 50,
    daysToHarvestMax: 65,
    wateringGuide:
        'Cucumbers are >90% water—water deeply at the root base every morning. Uneven watering makes fruit bitter or curved.',
    spacingGuide:
        '40–50 cm between plants × 100–120 cm between rows. Trellising on stakes/string produces straighter fruit and fewer fungal spots.',
    seasonAndWeatherNotes:
        'Warm weather speeds vine growth and pollination. In cooler highland nights (Arusha, Mbeya, Iringa), germination slows—wait for warm morning sun and avoid cold evening overhead watering.',
    whatToLookFor: [
      'White powdery patches on upper leaves: Powdery Mildew—improve airflow and avoid wetting leaves.',
      'Yellow angular spots on leaves: Downy Mildew, especially after humid nights.',
      'Stung, oozing young fruits: Melon/Cucumber Fruit Fly—remove affected fruit and dispose away from the bed.',
      'Aphids clustering on tender vine tips.',
    ],
    stageCareTips: [
      'Germination (Days 1–10): Direct-seed 2 cm deep in moist, loose soil; thin to the strongest seedling per hole.',
      'Vegetative (Weeks 2–4): Guide main vines onto trellis early before tendrils tangle.',
      'Flowering: Avoid spraying during morning hours when bees are pollinating flowers.',
      'Harvest: Pick every 2–3 days while skins are firm and green—leaving overripe fruit stops new flowers.',
    ],
    nutritionNotes:
        'Incorporate well-rotted compost/manure before sowing. Side-dress lightly once vines begin running, and support potassium/balanced nutrition at flowering. Always water before fertilizing.',
  ),
  'tz_pepper': CropFieldGuide(
    profileId: 'tz_pepper',
    commonName: 'Pepper',
    localNameSw: 'Pilipili',
    family: 'Solanaceae',
    daysToHarvestMin: 75,
    daysToHarvestMax: 95,
    wateringGuide:
        'Keep soil evenly moist, never waterlogged. Water at the base in the morning; peppers wilt quickly in dry heat but rot in standing water.',
    spacingGuide:
        '45–50 cm between plants × 60–75 cm between rows. Use light stakes for heavy-fruiting sweet peppers.',
    seasonAndWeatherNotes:
        'Thrives in warm conditions (20–30°C). Cool highland nights slow fruit set; dry windy spells increase thrips and mite pressure—mulching helps stabilize root temperature.',
    whatToLookFor: [
      'Curled, puckered young leaves: Thrips or mites—inspect undersides with close look.',
      'Sunken dark spots on fruit: Anthracnose or sunscald—remove affected fruit early.',
      'Sudden wilting of green plants even in moist soil: possible bacterial wilt—do not replant Solanaceae in the same spot.',
      'Aphids and whiteflies on new shoots.',
    ],
    stageCareTips: [
      'Nursery (4–6 weeks): Peppers germinate slower than tomatoes; keep seedbed evenly moist.',
      'Vegetative: Mulch around base and weed gently—pepper roots are shallow.',
      'Flowering: Steady watering prevents blossom drop.',
      'Harvest: Cut fruits with a clean knife/shears instead of pulling branches; regular picking boosts yield.',
    ],
    nutritionNotes:
        'Avoid excessive nitrogen once flowering starts (too much nitrogen grows leafy bushes with few peppers). Shift to balanced NPK support during flowering and fruiting.',
  ),
  'tz_african_eggplant': CropFieldGuide(
    profileId: 'tz_african_eggplant',
    commonName: 'African Eggplant',
    localNameSw: 'Ngogwe / Bilinganya',
    family: 'Solanaceae',
    daysToHarvestMin: 75,
    daysToHarvestMax: 95,
    wateringGuide:
        'Deep base watering 2–3 times per week (more often in sandy or hot lowland soil). Mulch well to conserve moisture.',
    spacingGuide:
        '60 cm between plants × 75–90 cm between rows to give bushy plants room for airflow.',
    seasonAndWeatherNotes:
        'Hardy across most Tanzania zones. In cool seasons growth slows slightly, while dry heat increases red spider mites—keep beds mulched and evenly watered.',
    whatToLookFor: [
      'Fine webbing and dusty bronzing on leaf undersides: Red Spider Mites during dry spells.',
      'Holes in shoots or young fruits: Shoot and Fruit Borer—prune wilted shoot tips immediately.',
      'Small round leaf holes: Flea Beetles on young transplants.',
      'Wilting on hot afternoons that does not recover overnight.',
    ],
    stageCareTips: [
      'Nursery: Raise seedlings for 4–5 weeks before transplanting on a cool afternoon.',
      'Vegetative: Earth up soil gently around the base for strong stem support.',
      'Flowering & Fruiting: Support heavy branches if needed so fruits stay clean.',
      'Harvest: Pick Ngogwe while firm and glossy (green/cream/yellow depending on variety) before seeds harden.',
    ],
    nutritionNotes:
        'Responds well to composted manure at planting plus light nitrogen top-dressing 3 weeks after transplant, then balanced NPK during continuous harvesting.',
  ),
  'tz_african_nightshade': CropFieldGuide(
    profileId: 'tz_african_nightshade',
    commonName: 'African Nightshade',
    localNameSw: 'Mnavu',
    family: 'Solanaceae',
    daysToHarvestMin: 35,
    daysToHarvestMax: 45,
    wateringGuide:
        'Water lightly and regularly in the morning so tender leaves stay soft and mild-tasting. Moisture stress makes leaves bitter and triggers early flowering.',
    spacingGuide:
        '20–30 cm between plants × 30–40 cm between rows for repeated leafy harvests.',
    seasonAndWeatherNotes:
        'Grows well in both cool highland and warm lowland areas. Cool weather produces especially tender leaves; in hot dry periods provide light afternoon shade or mulch.',
    whatToLookFor: [
      'Black aphids clustering under young leaves and growing tips.',
      'Small shot-holes from flea beetles on newly emerged seedlings.',
      'Early flowering spikes—pinch flowers off to keep the plant producing tender leaves.',
    ],
    stageCareTips: [
      'Germination: Mix tiny seeds with fine sand for even sowing; keep topsoil damp.',
      'Vegetative: Thin overcrowded seedlings early so stems branch strongly.',
      'Harvest: Begin picking tender shoots 4–5 weeks after sowing; harvest weekly to encourage fresh side shoots.',
    ],
    nutritionNotes:
        'Leafy crop that thrives on composted manure and moderate nitrogen after each harvest flush. Always rinse harvested leaves thoroughly.',
  ),
  'tz_okra': CropFieldGuide(
    profileId: 'tz_okra',
    commonName: 'Okra',
    localNameSw: 'Bamia',
    family: 'Malvaceae',
    daysToHarvestMin: 50,
    daysToHarvestMax: 60,
    wateringGuide:
        'Water deeply at the soil base 2–3 times weekly. Okra tolerates brief dry spells better than standing water, but steady moisture keeps pods tender.',
    spacingGuide:
        '30–40 cm between plants × 60–75 cm between rows. Direct-seed 2–3 cm deep.',
    seasonAndWeatherNotes:
        'Loves warm sunshine (24–35°C). In cool weather germination and pod growth slow noticeably—soak seeds in clean water overnight before sowing to speed emergence.',
    whatToLookFor: [
      'Yellow mosaic vein patterns on leaves: Yellow Vein Mosaic Virus (spread by whiteflies)—remove infected plants early.',
      'Aphids and ants along stems and under pods.',
      'Pods turning woody/fibrous if left on the plant too long.',
    ],
    stageCareTips: [
      'Germination: Pre-soak seeds 8–12 hours; thin to 1 strong plant per station.',
      'Vegetative: Keep bed weed-free in the first 4 weeks while plants establish.',
      'Harvest: Check every 2 days and cut pods when 7–10 cm long (snap easily at the tip). Wear gloves if hairs irritate skin.',
    ],
    nutritionNotes:
        'Apply compost/manure before sowing and a light side-dressing once flowering starts. Avoid over-fertilizing with nitrogen, which produces tall stems with fewer pods.',
  ),
  'tz_amaranth': CropFieldGuide(
    profileId: 'tz_amaranth',
    commonName: 'Amaranth',
    localNameSw: 'Mchicha',
    family: 'Amaranthaceae',
    daysToHarvestMin: 21,
    daysToHarvestMax: 35,
    wateringGuide:
        'Water gently every morning (use a fine watering can rose so tiny seedlings are not washed out). Keep topsoil consistently moist.',
    spacingGuide:
        'Broadcast thinly or sow in rows 20 cm apart; thin to 10–15 cm for cut-and-come-again harvests.',
    seasonAndWeatherNotes:
        'Fastest-maturing leafy crop in Tanzania—ideal for quick food and cash flow. Thrives in warm weather; in heavy rain raise beds slightly so roots do not rot.',
    whatToLookFor: [
      'Leaf-eating caterpillars and webworms rolling young leaves—hand-pick early in the morning.',
      'Tiny pale holes from beetles on young leaves.',
      'Damping-off (seedlings collapsing at soil line) if beds stay soggy overnight.',
    ],
    stageCareTips: [
      'Germination (Days 1–5): Mix fine seed with dry sand/ash for even distribution; cover very lightly.',
      'Vegetative (Weeks 2–3): Thin and weed early—Mchicha grows rapidly once established.',
      'Harvest (Weeks 3–5): Either uproot whole young plants at 21–28 days or cut tops leaving 10 cm stem for regrowth.',
    ],
    nutritionNotes:
        'Rich composted manure mixed into the top 15 cm of bed soil is usually enough for a fast 30-day cycle. Avoid late chemical sprays near harvest.',
  ),
  'tz_sukuma_wiki': CropFieldGuide(
    profileId: 'tz_sukuma_wiki',
    commonName: 'Sukuma Wiki',
    localNameSw: 'Sukumawiki',
    family: 'Brassicaceae',
    daysToHarvestMin: 45,
    daysToHarvestMax: 60,
    wateringGuide:
        'Water deeply at the base in the morning 3–4 times weekly. Consistent water keeps leaves crisp and sweet.',
    spacingGuide:
        '45 cm between plants × 60 cm between rows. Good airflow lowers fungal leaf spot.',
    seasonAndWeatherNotes:
        'Loves cooler weather (June–August and highlands)—leaves become sweeter and more tender. In hot lowland sun, mulch heavily to keep roots cool.',
    whatToLookFor: [
      'Small green caterpillars chewing windows in leaves: Diamondback Moth—check undersides twice weekly.',
      'Waxy grey-green cabbage aphids packed in leaf folds.',
      'V-shaped yellow lesions at leaf margins: Black Rot—avoid working in wet beds and rotate away from Brassicas.',
    ],
    stageCareTips: [
      'Nursery (3–4 weeks): Transplant strong seedlings with 4–5 true leaves in late afternoon.',
      'Vegetative: Mulch and weed regularly; remove yellowed oldest bottom leaves.',
      'Harvest: Pick outer mature leaves weekly while leaving the central growing crown intact for months of harvest.',
    ],
    nutritionNotes:
        'Heavy feeder of nitrogen and organic matter—mix compost before planting and side-dress lightly every 3–4 weeks of continuous harvest.',
  ),
  'tz_squash': CropFieldGuide(
    profileId: 'tz_squash',
    commonName: 'Squash / Pumpkin',
    localNameSw: 'Boga',
    family: 'Cucurbitaceae',
    daysToHarvestMin: 80,
    daysToHarvestMax: 110,
    wateringGuide:
        'Water deeply at the main root hill 2–3 times weekly in the morning. Avoid wetting the broad leaves in the evening.',
    spacingGuide:
        '100 cm between hills × 150–200 cm between rows—vines need generous ground space.',
    seasonAndWeatherNotes:
        'Thrives in warm sunny seasons. In rainy weather place a clean flat stone or dry grass pad under developing fruits so they do not rot on wet soil.',
    whatToLookFor: [
      'White floury coating on older leaves: Powdery Mildew—trim heavily affected old leaves for airflow.',
      'Young fruits shrivelling right after flowering: poor pollination—avoid spraying when bees visit morning blooms.',
      'Fruit fly stings on tender immature squash.',
    ],
    stageCareTips: [
      'Germination: Direct-seed 2–3 seeds per hill, 3 cm deep; thin to 1–2 strongest vines.',
      'Vegetative: Mulch around the main hill and guide vines away from pathways.',
      'Fruiting & Harvest: Tender pumpkin leaves (majani ya maboga) can be harvested sparingly; harvest mature pumpkins when rind is hard and stem begins drying.',
    ],
    nutritionNotes:
        'Plant on compost-enriched hills. A balanced side-dressing when vines start running supports strong flowering and fruit size.',
  ),
};

CropFieldGuide fieldGuideForCrop({
  required String profileId,
  required String commonName,
  required String localNameSw,
}) {
  final exact = kCropFieldLibrary[profileId];
  if (exact != null) return exact;

  final normalized = commonName.toLowerCase();
  for (final guide in kCropFieldLibrary.values) {
    if (normalized.contains(guide.commonName.toLowerCase())) {
      return guide;
    }
  }

  return CropFieldGuide(
    profileId: profileId,
    commonName: commonName,
    localNameSw: localNameSw,
    family: 'Garden Crop',
    daysToHarvestMin: 60,
    daysToHarvestMax: 75,
    wateringGuide:
        'Water slowly at the root base before 09:00 AM and check soil moisture 5 cm deep before watering.',
    spacingGuide:
        'Give plants enough room for morning air to dry leaves quickly and mulch around the root zone.',
    seasonAndWeatherNotes:
        'In rainy weather prioritize drainage and airflow; in dry spells mulch around roots to hold moisture.',
    whatToLookFor: [
      'Inspect leaf undersides twice weekly for aphids, caterpillars, or whiteflies.',
      'Remove heavily spotted oldest leaves early and avoid evening overhead watering.',
    ],
    stageCareTips: [
      'Seedling/Germination: Keep topsoil evenly moist without waterlogging.',
      'Vegetative: Mulch and weed early to reduce competition.',
      'Flowering & Harvest: Maintain steady watering and harvest cleanly at maturity.',
    ],
    nutritionNotes:
        'Use well-rotted compost at planting and follow Crop Planner or local agro-dealer label rates for top-dressing.',
  );
}

/// Practical homestead spacing & bed advice tailored to the farmer's own plot
/// (using cm first for East Africa, plus everyday foot-length / hand-span / cut-stick cues).
String homesteadSetupAdvice({
  required PlotModel? plot,
  required CropFieldGuide guide,
}) {
  final region = plot?.regionName ?? 'your area';
  final spacingHint = _practicalSpacingCue(guide.profileId);

  if (plot == null) {
    return 'Practical homestead spacing for ${guide.commonName}: $spacingHint. '
        'Cut a simple measuring stick to that length so planting stays even without a tape measure.';
  }

  switch (plot.plotType) {
    case PlotType.raisedBed:
      return 'For your Raised Bed in $region: keep bed width around 100–120 cm (about 4 adult foot-lengths) '
          'so you can reach the center from both sides without stepping on the loose soil, and 20–30 cm deep '
          '(about 1 foot-length). Space ${guide.commonName} at $spacingHint — cut a stick to that length to mark holes fast.';
    case PlotType.container:
      return 'For your Containers in $region: use a deep bucket, sack, or pot at least 25–30 cm deep '
          '(about 1 foot-length) with good drainage holes at the bottom. Give ${guide.commonName} $spacingHint '
          '(usually 1 strong fruiting plant per 20 L bucket, or a few leafy stems).';
    case PlotType.inGround:
      return 'For your In-Ground plot in $region: loosen soil 20–25 cm deep and form slight ridges in rainy months '
          'so roots never sit in standing water. Space ${guide.commonName} at $spacingHint — a cut measuring stick '
          'or paced foot-lengths keeps rows neat for weeding and airflow.';
    case PlotType.indoorWindow:
      return 'For your Indoor / Sheltered Window spot in $region: place ${guide.commonName} where it gets the '
          'brightest morning sun and rotate pots every few days. Spacing guide: $spacingHint.';
  }
}

String _practicalSpacingCue(String profileId) {
  switch (profileId) {
    case 'tz_tomato':
    case 'tz_african_eggplant':
      return '60 cm between plants (about 2 adult foot-lengths) × 90 cm between rows (3 foot-lengths)';
    case 'tz_pepper':
    case 'tz_sukuma_wiki':
      return '45–50 cm between plants (about 1.5 foot-lengths) × 60–75 cm between rows (2–2.5 foot-lengths)';
    case 'tz_cucumber':
      return '40–50 cm between plants (about 1.5 foot-lengths) × 100 cm between rows (about 3.5 foot-lengths)';
    case 'tz_okra':
      return '30–40 cm between plants (about 1 to 1.5 foot-lengths) × 60 cm between rows (2 foot-lengths)';
    case 'tz_african_nightshade':
      return '20–30 cm between plants (1 open hand-span to 1 foot-length) × 30–40 cm between rows';
    case 'tz_amaranth':
      return '10–15 cm between plants (about 1 palm width) in rows 20 cm apart (1 open hand-span)';
    case 'tz_squash':
      return '100 cm between hills (about 3.5 foot-lengths) × 150 cm between rows';
    default:
      return '30–60 cm between plants (1–2 adult foot-lengths depending on plant size)';
  }
}

