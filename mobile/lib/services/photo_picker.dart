import 'dart:typed_data';

import 'photo_picker_stub.dart'
    if (dart.library.html) 'photo_picker_web.dart'
    if (dart.library.io) 'photo_picker_io.dart' as impl;

enum PhotoPickMode {
  camera,
  galleryOrFile,
}

class PickedPhoto {
  const PickedPhoto({
    required this.fileName,
    required this.bytes,
  });

  final String fileName;
  final Uint8List bytes;
}

/// Picks a plant photo from the device camera or phone gallery / WhatsApp files.
Future<PickedPhoto?> pickPlantPhoto(PhotoPickMode mode) {
  return impl.pickPlantPhotoImpl(mode);
}
