// Simple Farm Contact Book (Suppliers & Buyers/Clients) + Search Helper.
// Keeps farm business contacts separate from the user's personal phonebook.

enum FarmContactCategory {
  supplier, // Agro-dealers, seedling vendors, agronomists
  buyer, // Market brokers, Kariakoo/regional buyers, local shops
}

/// Saved Mentor Q&A and search log entry so the farmer can browse past advice
/// ("what we talked about last week") and optionally delete older logs.
class MentorChatLogEntry {
  const MentorChatLogEntry({
    required this.id,
    required this.sessionId,
    required this.question,
    required this.answer,
    required this.dateIso,
  });

  final String id;
  final String sessionId;
  final String question;
  final String answer;
  final String dateIso;
}

class AgroSupplier {
  const AgroSupplier({
    required this.id,
    required this.name,
    required this.regionName,
    required this.townOrArea,
    required this.phoneNumber,
    required this.inputsStocked,
    this.category = FarmContactCategory.supplier,
    this.isUserAdded = false,
    this.isDemoPlaceholder = false,
    this.notes,
  });

  final String id;
  final String name;
  final String regionName;
  final String townOrArea;
  final String phoneNumber;
  final List<String> inputsStocked; // For suppliers: inputs stocked; for buyers: crops they buy
  final FarmContactCategory category;
  final bool isUserAdded;
  final bool isDemoPlaceholder;
  final String? notes;
}

/// Starter Tanzania regional agro-dealer & buyer placeholders.
/// Marked `isDemoPlaceholder: true` so farmers replace/add their real trusted contacts.
const List<AgroSupplier> kStarterTanzaniaSuppliers = [
  AgroSupplier(
    id: 'sup_dodoma_1',
    name: 'Dodoma Agro-Vet & Pembejeo Center',
    regionName: 'Dodoma',
    townOrArea: 'Majengo / Sabasaba Market',
    phoneNumber: '+255 7XX XXX XXX (Verify local number)',
    inputsStocked: ['DAP', 'CAN', 'Urea', 'NPK 17:17:17', 'Calcium-Boron Foliar', 'Vegetable Seeds'],
    category: FarmContactCategory.supplier,
    isDemoPlaceholder: true,
    notes: 'Sample listing — tap "+ Add Contact" to save your trusted Dodoma agro-dealer.',
  ),
  AgroSupplier(
    id: 'sup_dsm_1',
    name: 'Kariakoo / Ilala Pembejeo Agro-Dealer',
    regionName: 'Dar es Salaam',
    townOrArea: 'Kariakoo / Ilala',
    phoneNumber: '+255 7XX XXX XXX (Verify local number)',
    inputsStocked: ['DAP', 'Urea', 'NPK', 'Foliar Sprays', 'Seedling Trays'],
    category: FarmContactCategory.supplier,
    isDemoPlaceholder: true,
    notes: 'Sample listing — save your preferred Dar es Salaam agro-dealer below.',
  ),
  AgroSupplier(
    id: 'sup_arusha_1',
    name: 'Arusha Kilimo & Seedlings Hub',
    regionName: 'Arusha',
    townOrArea: 'Central Market / Tengeru',
    phoneNumber: '+255 7XX XXX XXX (Verify local number)',
    inputsStocked: ['Vegetable Seedlings', 'DAP', 'CAN', 'NPK 17:17:17', 'Calcium-Boron Foliar'],
    category: FarmContactCategory.supplier,
    isDemoPlaceholder: true,
    notes: 'Sample listing — save your Tengeru / Arusha agro-dealer below.',
  ),
  AgroSupplier(
    id: 'sup_morogoro_1',
    name: 'Morogoro Agro-Inputs & Seeds',
    regionName: 'Morogoro',
    townOrArea: 'Msamvu / Town Center',
    phoneNumber: '+255 7XX XXX XXX (Verify local number)',
    inputsStocked: ['DAP', 'Urea', 'NPK', 'Vegetable Seeds', 'Sprayers'],
    category: FarmContactCategory.supplier,
    isDemoPlaceholder: true,
    notes: 'Sample listing — save your local Morogoro agro-dealer below.',
  ),
];

/// Builds a Google Search query string for finding agro-dealers or agronomists near the farmer's region.
String buildAgroSupplierSearchQuery({
  required String regionName,
  String? inputNeeded,
}) {
  final item = (inputNeeded == null || inputNeeded.trim().isEmpty)
      ? 'pembejeo agro dealer agronomist'
      : inputNeeded.trim();
  return 'agro dealer $item $regionName Tanzania phone number';
}

/// Builds a practical phone-call price & stock check script for the farmer.
String buildPriceCheckScript({
  required String? inputNeeded,
  required String regionName,
}) {
  final item = (inputNeeded == null || inputNeeded.trim().isEmpty)
      ? 'DAP / CAN / NPK fertilizer'
      : inputNeeded.trim();
  return 'Habari! I am farming in $regionName. Do you have $item in stock today, and what is the price per kg or bottle?';
}
