import 'dart:io';

import 'package:flutter/services.dart';

const MethodChannel _storageChannel =
    MethodChannel('com.example.ai_gardening_mentor/hybrid_ai');

Directory _fallbackDir() {
  final base = Directory('${Directory.systemTemp.path}/agm_checklists');
  if (!base.existsSync()) {
    base.createSync(recursive: true);
  }
  return base;
}

/// Persists checklists into durable app-private `context.filesDir` on Android
/// (surviving restarts & cache eviction). Falls back to temp dir only in CLI/unit tests.
Future<void> writeChecklistString(String key, String value) async {
  if (Platform.isAndroid) {
    await _storageChannel.invokeMethod<void>(
      'writeChecklist',
      {'key': key, 'value': value},
    );
    return;
  }
  final file = File('${_fallbackDir().path}/$key.json');
  await file.writeAsString(value, flush: true);
}

Future<String?> readChecklistString(String key) async {
  if (Platform.isAndroid) {
    return _storageChannel.invokeMethod<String>(
      'readChecklist',
      {'key': key},
    );
  }
  final file = File('${_fallbackDir().path}/$key.json');
  if (!await file.exists()) return null;
  return file.readAsString();
}

Future<void> deleteChecklistString(String key) async {
  if (Platform.isAndroid) {
    await _storageChannel.invokeMethod<void>(
      'deleteChecklist',
      {'key': key},
    );
    return;
  }
  final file = File('${_fallbackDir().path}/$key.json');
  if (await file.exists()) {
    await file.delete();
  }
}
