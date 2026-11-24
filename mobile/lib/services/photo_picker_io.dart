import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import 'photo_picker.dart';

const MethodChannel _photoChannel = MethodChannel('ai_gardening_mentor/photo_picker');

/// Native Android/iOS photo picker backed by a platform MethodChannel.
Future<PickedPhoto?> pickPlantPhotoImpl(PhotoPickMode mode) async {
  if (!Platform.isAndroid && !Platform.isIOS) {
    return null;
  }
  try {
    final result = await _photoChannel.invokeMapMethod<String, dynamic>(
      'pickPhoto',
      <String, dynamic>{
        'mode': mode == PhotoPickMode.camera ? 'camera' : 'galleryOrFile',
      },
    );
    if (result == null) return null;
    final rawBytes = result['bytes'];
    if (rawBytes is! Uint8List || rawBytes.isEmpty) return null;
    final fileName = (result['fileName'] as String?)?.trim();
    return PickedPhoto(
      fileName: (fileName == null || fileName.isEmpty) ? 'plant_photo.jpg' : fileName,
      bytes: rawBytes,
    );
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
