import '../models/garden_models.dart';

/// 9 Starter Tanzania Crops (docs/phase-0-decisions.md).
const List<TanzaniaCropOption> kTanzaniaCrops = [
  TanzaniaCropOption(
    profileId: 'tz_tomato',
    commonName: 'Tomato',
    localNameSw: 'Nyanya',
    family: 'Solanaceae',
    defaultMethod: PlantingMethod.transplant,
  ),
  TanzaniaCropOption(
    profileId: 'tz_pepper',
    commonName: 'Pepper',
    localNameSw: 'Pilipili',
    family: 'Solanaceae',
    defaultMethod: PlantingMethod.transplant,
  ),
  TanzaniaCropOption(
    profileId: 'tz_african_eggplant',
    commonName: 'African Eggplant',
    localNameSw: 'Ngogwe / Bilinganya',
    family: 'Solanaceae',
    defaultMethod: PlantingMethod.transplant,
  ),
  TanzaniaCropOption(
    profileId: 'tz_african_nightshade',
    commonName: 'African Nightshade',
    localNameSw: 'Mnavu',
    family: 'Solanaceae',
    defaultMethod: PlantingMethod.directSeed,
  ),
  TanzaniaCropOption(
    profileId: 'tz_okra',
    commonName: 'Okra',
    localNameSw: 'Bamia',
    family: 'Malvaceae',
    defaultMethod: PlantingMethod.directSeed,
  ),
  TanzaniaCropOption(
    profileId: 'tz_amaranth',
    commonName: 'Amaranth',
    localNameSw: 'Mchicha',
    family: 'Amaranthaceae',
    defaultMethod: PlantingMethod.directSeed,
  ),
  TanzaniaCropOption(
    profileId: 'tz_sukuma_wiki',
    commonName: 'Sukuma Wiki',
    localNameSw: 'Sukumawiki',
    family: 'Brassicaceae',
    defaultMethod: PlantingMethod.transplant,
  ),
  TanzaniaCropOption(
    profileId: 'tz_cucumber',
    commonName: 'Cucumber',
    localNameSw: 'Tango',
    family: 'Cucurbitaceae',
    defaultMethod: PlantingMethod.directSeed,
  ),
  TanzaniaCropOption(
    profileId: 'tz_squash',
    commonName: 'Squash / Pumpkin',
    localNameSw: 'Boga',
    family: 'Cucurbitaceae',
    defaultMethod: PlantingMethod.directSeed,
  ),
];

const List<String> kTanzaniaRegions = [
  'Dar es Salaam',
  'Arusha',
  'Kilimanjaro',
  'Morogoro',
  'Dodoma',
  'Mwanza',
  'Mbeya',
  'Tanga',
  'Zanzibar',
  'Iringa',
];

const Map<String, ({double lat, double lng})> kTanzaniaRegionCoords = {
  'Dar es Salaam': (lat: -6.7924, lng: 39.2083),
  'Arusha': (lat: -3.3869, lng: 36.6830),
  'Kilimanjaro': (lat: -3.3349, lng: 37.3404),
  'Morogoro': (lat: -6.8278, lng: 37.6591),
  'Dodoma': (lat: -6.1630, lng: 35.7516),
  'Mwanza': (lat: -2.5164, lng: 32.9175),
  'Mbeya': (lat: -8.9094, lng: 33.4608),
  'Tanga': (lat: -5.0689, lng: 39.0988),
  'Zanzibar': (lat: -6.1659, lng: 39.2026),
  'Iringa': (lat: -7.7700, lng: 35.6900),
};

const SourceCitation kGrowHowFixtureCitation = SourceCitation(
  sourceId: 'ewskt_growhow_tropical_veg',
  revision: 'v1-fixture',
  passageId: 'root_zone_watering_am',
  publisher: 'East-West Seed Knowledge Transfer (EWS-KT)',
  title: 'GrowHow Tropical Vegetable Production Guides (Prototype Fixture)',
  canonicalUrl: 'https://growhow.ews-kt.com/in/en',
);
