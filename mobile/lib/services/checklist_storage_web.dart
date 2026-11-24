import 'dart:js_interop';

@JS('window.localStorage')
external _LocalStorage get _localStorage;

extension type _LocalStorage(JSObject _) implements JSObject {
  external JSString? getItem(JSString key);
  external void setItem(JSString key, JSString value);
  external void removeItem(JSString key);
}

Future<void> writeChecklistString(String key, String value) async {
  try {
    _localStorage.setItem(key.toJS, value.toJS);
  } catch (_) {}
}

Future<String?> readChecklistString(String key) async {
  try {
    return _localStorage.getItem(key.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}

Future<void> deleteChecklistString(String key) async {
  try {
    _localStorage.removeItem(key.toJS);
  } catch (_) {}
}
