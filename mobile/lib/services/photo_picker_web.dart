// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'photo_picker.dart';

/// Web / Android Chrome photo picker supporting both direct Camera capture
/// (`capture="environment"`) and Gallery / WhatsApp file upload.
Future<PickedPhoto?> pickPlantPhotoImpl(PhotoPickMode mode) async {
  final completer = Completer<PickedPhoto?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';

  if (mode == PhotoPickMode.camera) {
    input.setAttribute('capture', 'environment');
  }

  input.onChange.first.then((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        if (!completer.isCompleted) {
          completer.complete(
            PickedPhoto(fileName: file.name, bytes: Uint8List.view(result)),
          );
        }
      } else if (result is Uint8List) {
        if (!completer.isCompleted) {
          completer.complete(PickedPhoto(fileName: file.name, bytes: result));
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    });
    reader.onError.first.then((_) {
      if (!completer.isCompleted) completer.complete(null);
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}
