import 'photo_picker.dart';

/// Non-web fallback (used in unit/widget tests until native image_picker is wired).
Future<PickedPhoto?> pickPlantPhotoImpl(PhotoPickMode mode) async {
  return null;
}
