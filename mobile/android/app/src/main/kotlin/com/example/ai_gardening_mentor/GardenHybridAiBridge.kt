package com.example.ai_gardening_mentor

import android.content.Context
import android.os.Handler
import android.os.Looper
import java.io.File
import com.google.firebase.Firebase
import com.google.firebase.ai.InferenceMode
import com.google.firebase.ai.InferenceSource
import com.google.firebase.ai.OnDeviceConfig
import com.google.firebase.ai.ai
import com.google.firebase.ai.ondevice.DownloadStatus
import com.google.firebase.ai.ondevice.FirebaseAIOnDevice
import com.google.firebase.ai.ondevice.OnDeviceModelStatus
import com.google.firebase.ai.type.GenerativeBackend
import com.google.firebase.ai.type.PublicPreviewAPI
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import java.util.concurrent.ConcurrentHashMap

@OptIn(PublicPreviewAPI::class)
class GardenHybridAiBridge(
    private val appContext: Context,
    messenger: BinaryMessenger
) :
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val progressChannel = EventChannel(messenger, PROGRESS_CHANNEL_NAME)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val activeJobs = ConcurrentHashMap<String, Job>()
    @Volatile
    private var progressSink: EventChannel.EventSink? = null

    init {
        methodChannel.setMethodCallHandler(this)
        progressChannel.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        progressSink = events
    }

    override fun onCancel(arguments: Any?) {
        progressSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "checkCapability" -> handleCheckCapability(result)
            "prepareModel" -> handlePrepareModel(result)
            "generateChecklist" -> handleGenerateChecklist(call, result)
            "cancel" -> {
                val reqId = call.argument<String>("requestId")
                if (reqId != null) {
                    activeJobs.remove(reqId)?.cancel()
                }
                result.success(null)
            }
            "writeChecklist" -> {
                val key = call.argument<String>("key")
                val value = call.argument<String>("value")
                if (key == null || value == null) {
                    result.error("INVALID_ARGS", "key and value required", null)
                    return
                }
                scope.launch {
                    try {
                        val dir = File(appContext.filesDir, "agm_checklists").apply { mkdirs() }
                        File(dir, "$key.json").writeText(value)
                        mainHandler.post { result.success(null) }
                    } catch (err: Throwable) {
                        mainHandler.post { result.error("STORAGE_WRITE_ERROR", err.message, null) }
                    }
                }
            }
            "readChecklist" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.success(null)
                    return
                }
                scope.launch {
                    try {
                        val file = File(File(appContext.filesDir, "agm_checklists"), "$key.json")
                        val content = if (file.exists()) file.readText() else null
                        mainHandler.post { result.success(content) }
                    } catch (err: Throwable) {
                        mainHandler.post { result.error("STORAGE_READ_ERROR", err.message, null) }
                    }
                }
            }
            "deleteChecklist" -> {
                val key = call.argument<String>("key")
                if (key == null) {
                    result.success(null)
                    return
                }
                scope.launch {
                    try {
                        val file = File(File(appContext.filesDir, "agm_checklists"), "$key.json")
                        if (file.exists()) file.delete()
                        mainHandler.post { result.success(null) }
                    } catch (err: Throwable) {
                        mainHandler.post { result.error("STORAGE_DELETE_ERROR", err.message, null) }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun handleCheckCapability(result: MethodChannel.Result) {
        scope.launch {
            try {
                val status = FirebaseAIOnDevice.checkStatus()
                val mapped = when (status) {
                    OnDeviceModelStatus.AVAILABLE -> mapOf(
                        "status" to "ready",
                        "platformLabel" to "Android (AICore + Firebase AI Logic)",
                        "modelIdentity" to "Gemini Nano (AICore)",
                        "message" to "On-device model is available and ready for offline checklist generation."
                    )
                    OnDeviceModelStatus.DOWNLOADABLE -> mapOf(
                        "status" to "downloadAvailable",
                        "platformLabel" to "Android (AICore + Firebase AI Logic)",
                        "modelIdentity" to "Gemini Nano (AICore)",
                        "message" to "On-device model can be downloaded via 'Prepare offline AI'."
                    )
                    OnDeviceModelStatus.DOWNLOADING -> mapOf(
                        "status" to "downloading",
                        "platformLabel" to "Android (AICore + Firebase AI Logic)",
                        "modelIdentity" to "Gemini Nano (AICore)",
                        "message" to "On-device model is currently downloading via AICore."
                    )
                    else -> mapOf(
                        "status" to "unsupported",
                        "platformLabel" to "Android (AICore + Firebase AI Logic)",
                        "message" to "On-device Gemini Nano is not available on this Android device (status: $status). Cloud fallback remains available when online."
                    )
                }
                mainHandler.post { result.success(mapped) }
            } catch (err: Throwable) {
                mainHandler.post {
                    result.success(
                        mapOf(
                            "status" to "unsupported",
                            "platformLabel" to "Android (AICore + Firebase AI Logic)",
                            "message" to "On-device capability check unavailable: ${err.message ?: err.javaClass.simpleName}"
                        )
                    )
                }
            }
        }
    }

    private fun handlePrepareModel(result: MethodChannel.Result) {
        scope.launch {
            try {
                var totalBytes = 0L
                FirebaseAIOnDevice.download().collect { dlStatus ->
                    when (dlStatus) {
                        is DownloadStatus.DownloadStarted -> {
                            totalBytes = dlStatus.bytesToDownload
                            emitProgress(
                                mapOf(
                                    "status" to "downloading",
                                    "downloadSizeBytes" to totalBytes,
                                    "downloadProgress" to 0.0,
                                    "message" to "Downloading on-device model..."
                                )
                            )
                        }
                        is DownloadStatus.DownloadInProgress -> {
                            val ratio = if (totalBytes > 0L) {
                                dlStatus.totalBytesDownloaded.toDouble() / totalBytes.toDouble()
                            } else {
                                0.0
                            }
                            emitProgress(
                                mapOf(
                                    "status" to "downloading",
                                    "downloadSizeBytes" to totalBytes,
                                    "downloadProgress" to ratio.coerceIn(0.0, 1.0),
                                    "message" to "Downloading on-device model..."
                                )
                            )
                        }
                        is DownloadStatus.DownloadCompleted -> {
                            emitProgress(
                                mapOf(
                                    "status" to "ready",
                                    "modelIdentity" to "Gemini Nano (AICore)",
                                    "downloadProgress" to 1.0,
                                    "message" to "On-device model prepared and ready."
                                )
                            )
                        }
                        is DownloadStatus.DownloadFailed -> {
                            emitProgress(
                                mapOf(
                                    "status" to "error",
                                    "message" to "Download failed: $dlStatus"
                                )
                            )
                        }
                        else -> Unit
                    }
                }
                val finalStatus = FirebaseAIOnDevice.checkStatus()
                val mappedStatus = if (finalStatus == OnDeviceModelStatus.AVAILABLE) "ready" else "error"
                mainHandler.post {
                    result.success(
                        mapOf(
                            "status" to mappedStatus,
                            "modelIdentity" to if (mappedStatus == "ready") "Gemini Nano (AICore)" else null,
                            "downloadProgress" to if (mappedStatus == "ready") 1.0 else 0.0,
                            "message" to if (mappedStatus == "ready") {
                                "On-device model prepared and ready."
                            } else {
                                "Model preparation did not reach ready state ($finalStatus)."
                            }
                        )
                    )
                }
            } catch (err: Throwable) {
                mainHandler.post {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "message" to "Prepare model error: ${err.message ?: err.javaClass.simpleName}"
                        )
                    )
                }
            }
        }
    }

    private fun handleGenerateChecklist(call: MethodCall, result: MethodChannel.Result) {
        val prompt = call.argument<String>("prompt") ?: ""
        val modeStr = call.argument<String>("mode") ?: "preferOnDevice"
        val requestId = call.argument<String>("requestId") ?: "android_${System.currentTimeMillis()}"
        val cloudModel = call.argument<String>("cloudModel") ?: "gemini-3.8-flash"

        val mode = when (modeStr) {
            "onlyOnDevice" -> InferenceMode.ONLY_ON_DEVICE
            "onlyInCloud" -> InferenceMode.ONLY_IN_CLOUD
            else -> InferenceMode.PREFER_ON_DEVICE
        }

        val job = scope.launch {
            val startMs = System.currentTimeMillis()
            try {
                val model = Firebase.ai(backend = GenerativeBackend.googleAI()).generativeModel(
                    modelName = cloudModel,
                    onDeviceConfig = OnDeviceConfig(mode = mode)
                )
                val response = model.generateContent(prompt)
                val elapsedMs = (System.currentTimeMillis() - startMs).toInt()
                val source = when (response.inferenceSource) {
                    InferenceSource.ON_DEVICE -> "onDevice"
                    InferenceSource.IN_CLOUD -> "inCloud"
                    else -> "unknown"
                }
                val text = response.text?.trim().orEmpty()
                val identity = if (source == "onDevice") "Gemini Nano (AICore)" else cloudModel
                mainHandler.post {
                    result.success(
                        mapOf(
                            "requestId" to requestId,
                            "text" to text,
                            "inferenceSource" to source,
                            "elapsedMs" to elapsedMs,
                            "modelIdentity" to identity
                        )
                    )
                }
            } catch (err: Throwable) {
                val elapsedMs = (System.currentTimeMillis() - startMs).toInt()
                mainHandler.post {
                    result.success(
                        mapOf(
                            "requestId" to requestId,
                            "inferenceSource" to "unknown",
                            "elapsedMs" to elapsedMs,
                            "errorCode" to "INFERENCE_FAILED",
                            "errorMessage" to (err.message ?: err.javaClass.simpleName)
                        )
                    )
                }
            } finally {
                activeJobs.remove(requestId)
            }
        }
        activeJobs[requestId] = job
    }

    private fun emitProgress(payload: Map<String, Any?>) {
        mainHandler.post { progressSink?.success(payload) }
    }

    fun dispose() {
        activeJobs.values.forEach { it.cancel() }
        activeJobs.clear()
        scope.cancel()
        methodChannel.setMethodCallHandler(null)
        progressChannel.setStreamHandler(null)
    }

    companion object {
        const val METHOD_CHANNEL_NAME = "com.example.ai_gardening_mentor/hybrid_ai"
        const val PROGRESS_CHANNEL_NAME = "com.example.ai_gardening_mentor/hybrid_ai_progress"
    }
}
