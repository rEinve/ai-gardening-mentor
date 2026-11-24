package com.example.ai_gardening_mentor

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

class GardenPhotoPickerBridge(
    private val activity: Activity,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "ai_gardening_mentor/photo_picker")
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    private var pendingResult: MethodChannel.Result? = null
    private var pendingCameraFile: File? = null

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickPhoto") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error("BUSY", "Another photo selection is already in progress.", null)
            return
        }

        val mode = call.argument<String>("mode") ?: "galleryOrFile"
        pendingResult = result

        if (mode == "camera") {
            launchCamera()
        } else {
            launchGallery()
        }
    }

    private fun launchCamera() {
        try {
            val captureDir = File(activity.cacheDir, "camera_captures").apply { mkdirs() }
            val photoFile = File(captureDir, "capture_${System.currentTimeMillis()}.jpg")
            pendingCameraFile = photoFile

            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                photoFile,
            )
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, uri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            if (intent.resolveActivity(activity.packageManager) == null) {
                finishWithError("NO_CAMERA", "No camera app available on this device.")
                return
            }
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CAMERA)
        } catch (t: Throwable) {
            finishWithError("CAMERA_ERROR", t.message ?: "Failed to open camera.")
        }
    }

    private fun launchGallery() {
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            val chooser = Intent.createChooser(intent, "Select plant photo")
            @Suppress("DEPRECATION")
            activity.startActivityForResult(chooser, REQUEST_GALLERY)
        } catch (t: Throwable) {
            finishWithError("PICKER_ERROR", t.message ?: "Failed to open photo picker.")
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CAMERA && requestCode != REQUEST_GALLERY) {
            return false
        }

        val result = pendingResult
        val cameraFile = pendingCameraFile
        pendingResult = null
        pendingCameraFile = null

        if (result == null) {
            cameraFile?.delete()
            return true
        }

        if (resultCode != Activity.RESULT_OK) {
            cameraFile?.delete()
            result.success(null)
            return true
        }

        if (requestCode == REQUEST_CAMERA) {
            ioExecutor.execute {
                try {
                    val bytes = if (cameraFile != null && cameraFile.exists() && cameraFile.length() > 0) {
                        cameraFile.readBytes()
                    } else {
                        null
                    }
                    val name = cameraFile?.name ?: "camera_photo.jpg"
                    cameraFile?.delete()
                    mainHandler.post {
                        if (bytes != null && bytes.isNotEmpty()) {
                            result.success(mapOf("fileName" to name, "bytes" to bytes))
                        } else {
                            result.success(null)
                        }
                    }
                } catch (t: Throwable) {
                    cameraFile?.delete()
                    mainHandler.post {
                        result.error("READ_ERROR", t.message ?: "Failed to read captured photo.", null)
                    }
                }
            }
            return true
        }

        val uri: Uri? = data?.data
        if (uri == null) {
            result.success(null)
            return true
        }

        ioExecutor.execute {
            try {
                val bytes = activity.contentResolver.openInputStream(uri)?.use { it.readBytes() }
                val fileName = resolveDisplayName(uri) ?: "uploaded_photo.jpg"
                mainHandler.post {
                    if (bytes != null && bytes.isNotEmpty()) {
                        result.success(mapOf("fileName" to fileName, "bytes" to bytes))
                    } else {
                        result.success(null)
                    }
                }
            } catch (t: Throwable) {
                mainHandler.post {
                    result.error("READ_ERROR", t.message ?: "Failed to read selected photo.", null)
                }
            }
        }
        return true
    }

    private fun resolveDisplayName(uri: Uri): String? {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (idx >= 0) return cursor.getString(idx)
                }
            }
        return uri.lastPathSegment
    }

    private fun finishWithError(code: String, message: String) {
        val result = pendingResult
        pendingResult = null
        pendingCameraFile?.delete()
        pendingCameraFile = null
        result?.error(code, message, null)
    }

    fun dispose() {
        channel.setMethodCallHandler(null)
        pendingResult = null
        pendingCameraFile?.delete()
        pendingCameraFile = null
        ioExecutor.shutdownNow()
    }

    companion object {
        private const val REQUEST_CAMERA = 4101
        private const val REQUEST_GALLERY = 4102
    }
}
