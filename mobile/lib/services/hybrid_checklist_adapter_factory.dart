import 'hybrid_checklist_contract.dart';
import 'hybrid_checklist_adapter_io.dart'
    if (dart.library.js_interop) 'hybrid_checklist_adapter_web.dart' as platform;

HybridChecklistAdapter createHybridChecklistAdapter() {
  return platform.createPlatformHybridAdapter();
}
