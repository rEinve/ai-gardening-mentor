package com.example.ai_gardening_mentor

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var hybridAiBridge: GardenHybridAiBridge? = null
    private var photoPickerBridge: GardenPhotoPickerBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        hybridAiBridge = GardenHybridAiBridge(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger
        )
        photoPickerBridge = GardenPhotoPickerBridge(
            this,
            flutterEngine.dartExecutor.binaryMessenger
        )
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (photoPickerBridge?.onActivityResult(requestCode, resultCode, data) == true) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        photoPickerBridge?.dispose()
        photoPickerBridge = null
        hybridAiBridge?.dispose()
        hybridAiBridge = null
        super.onDestroy()
    }
}
