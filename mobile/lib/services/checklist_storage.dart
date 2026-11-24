import 'dart:convert';

import 'checklist_storage_io.dart'
    if (dart.library.js_interop) 'checklist_storage_web.dart' as impl;

class PersistedChecklistRecord {
  const PersistedChecklistRecord({
    required this.accountId,
    required this.cropStage,
    required this.observation,
    required this.checklistText,
    required this.savedAtIso,
    required this.originalSource,
    this.modelIdentity,
  });

  final String accountId;
  final String cropStage;
  final String observation;
  final String checklistText;
  final String savedAtIso;
  final String originalSource;
  final String? modelIdentity;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'cropStage': cropStage,
        'observation': observation,
        'checklistText': checklistText,
        'savedAtIso': savedAtIso,
        'originalSource': originalSource,
        'modelIdentity': modelIdentity,
      };

  static PersistedChecklistRecord? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final accountId = json['accountId'] as String?;
    final checklistText = json['checklistText'] as String?;
    if (accountId == null || checklistText == null) return null;
    return PersistedChecklistRecord(
      accountId: accountId,
      cropStage: (json['cropStage'] as String?) ?? 'Vegetative Growth',
      observation: (json['observation'] as String?) ?? '',
      checklistText: checklistText,
      savedAtIso: (json['savedAtIso'] as String?) ?? '',
      originalSource: (json['originalSource'] as String?) ?? 'unknown',
      modelIdentity: json['modelIdentity'] as String?,
    );
  }
}

/// Account-scoped durable storage for the Offline Care Checklist.
/// Ensures sign-out or switching accounts cannot expose another user's data.
class AccountChecklistStorage {
  /// Optional in-memory override for Flutter widget tests (`FakeAsync` safe).
  static Map<String, String>? debugMemoryStore;

  static String _keyFor(String accountId) {
    final safe = accountId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'agm_saved_checklist_$safe';
  }

  static Future<void> save(PersistedChecklistRecord record) async {
    final key = _keyFor(record.accountId);
    final payload = jsonEncode(record.toJson());
    if (debugMemoryStore != null) {
      debugMemoryStore![key] = payload;
      return;
    }
    await impl.writeChecklistString(key, payload);
  }

  static Future<PersistedChecklistRecord?> load(String accountId) async {
    final key = _keyFor(accountId);
    final raw = debugMemoryStore != null
        ? debugMemoryStore![key]
        : await impl.readChecklistString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final record = PersistedChecklistRecord.fromJson(decoded);
      if (record == null || record.accountId != accountId) return null;
      return record;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String accountId) async {
    final key = _keyFor(accountId);
    if (debugMemoryStore != null) {
      debugMemoryStore!.remove(key);
      return;
    }
    await impl.deleteChecklistString(key);
  }
}

class PersistedGardenProfile {
  const PersistedGardenProfile({
    required this.accountId,
    required this.plotId,
    required this.plotName,
    required this.regionName,
    required this.plotTypeName,
    required this.rainExposureName,
    required this.sunlightExposureName,
    this.farmAreaLabel,
    this.crops = const [],
    this.batchPlans = const [],
    this.farmContacts = const [],
    this.cropNotes = const [],
  });

  final String accountId;
  final String plotId;
  final String plotName;
  final String regionName;
  final String plotTypeName;
  final String rainExposureName;
  final String sunlightExposureName;
  final String? farmAreaLabel;
  final List<Map<String, dynamic>> crops;
  final List<Map<String, dynamic>> batchPlans;
  final List<Map<String, dynamic>> farmContacts;
  final List<Map<String, dynamic>> cropNotes;

  Map<String, dynamic> toJson() => {
        'accountId': accountId,
        'plotId': plotId,
        'plotName': plotName,
        'regionName': regionName,
        'plotTypeName': plotTypeName,
        'rainExposureName': rainExposureName,
        'sunlightExposureName': sunlightExposureName,
        'farmAreaLabel': farmAreaLabel,
        'crops': crops,
        'batchPlans': batchPlans,
        'farmContacts': farmContacts,
        'cropNotes': cropNotes,
      };

  static PersistedGardenProfile? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final accountId = json['accountId'] as String?;
    final plotId = json['plotId'] as String?;
    final plotName = json['plotName'] as String?;
    final regionName = json['regionName'] as String?;
    if (accountId == null ||
        plotId == null ||
        plotName == null ||
        regionName == null) {
      return null;
    }
    final rawCrops = json['crops'];
    final crops = rawCrops is List
        ? rawCrops
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final rawBatches = json['batchPlans'];
    final batchPlans = rawBatches is List
        ? rawBatches
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final rawContacts = json['farmContacts'];
    final farmContacts = rawContacts is List
        ? rawContacts
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final rawNotes = json['cropNotes'];
    final cropNotes = rawNotes is List
        ? rawNotes
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    return PersistedGardenProfile(
      accountId: accountId,
      plotId: plotId,
      plotName: plotName,
      regionName: regionName,
      plotTypeName: (json['plotTypeName'] as String?) ?? 'inGround',
      rainExposureName: (json['rainExposureName'] as String?) ?? 'exposed',
      sunlightExposureName: (json['sunlightExposureName'] as String?) ?? 'fullSun',
      farmAreaLabel: json['farmAreaLabel'] as String?,
      crops: crops,
      batchPlans: batchPlans,
      farmContacts: farmContacts,
      cropNotes: cropNotes,
    );
  }
}

/// Account-scoped durable storage for the user's garden profile & location settings.
class AccountGardenProfileStorage {
  static String _keyFor(String accountId) {
    final safe = accountId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'agm_garden_profile_$safe';
  }

  static Future<void> save(PersistedGardenProfile profile) async {
    final key = _keyFor(profile.accountId);
    final payload = jsonEncode(profile.toJson());
    if (AccountChecklistStorage.debugMemoryStore != null) {
      AccountChecklistStorage.debugMemoryStore![key] = payload;
      return;
    }
    await impl.writeChecklistString(key, payload);
  }

  static Future<PersistedGardenProfile?> load(String accountId) async {
    final key = _keyFor(accountId);
    final raw = AccountChecklistStorage.debugMemoryStore != null
        ? AccountChecklistStorage.debugMemoryStore![key]
        : await impl.readChecklistString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final profile = PersistedGardenProfile.fromJson(decoded);
      if (profile == null || profile.accountId != accountId) return null;
      return profile;
    } catch (_) {
      return null;
    }
  }
}
