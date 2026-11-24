import { initializeApp, getApps, getApp } from "firebase/app";
import { initializeAppCheck, ReCaptchaEnterpriseProvider } from "firebase/app-check";
import { getAuth } from "firebase/auth";
import { getAI, getGenerativeModel, GoogleAIBackend, InferenceMode } from "firebase/ai";

let _ai = null;
let _appCheckInitialized = false;
let _cachedConfigKey = "";
const _cancelled = new Set();

function resolveMode(modeStr) {
  switch (modeStr) {
    case "onlyOnDevice":
      return InferenceMode.ONLY_ON_DEVICE;
    case "onlyInCloud":
      return InferenceMode.ONLY_IN_CLOUD;
    case "preferOnDevice":
    default:
      return InferenceMode.PREFER_ON_DEVICE;
  }
}

function getOrInitAi(config) {
  const key = `${config.projectId || ""}:${config.apiKey || ""}:${config.recaptchaSiteKey || ""}`;
  if (_ai && _cachedConfigKey === key) return _ai;

  let app;
  const existing = getApps();
  if (existing.length > 0) {
    app = getApp();
  } else {
    app = initializeApp({
      apiKey: config.apiKey,
      appId: config.appId,
      messagingSenderId: config.messagingSenderId,
      projectId: config.projectId,
      authDomain: config.authDomain,
      storageBucket: config.storageBucket,
    });
  }

  // Bind Firebase Auth on this SDK instance so IndexedDB auth state is shared
  // with FlutterFire on the same origin for authenticated cloud fallback calls.
  try {
    getAuth(app);
  } catch (_) {}

  // Wire Firebase App Check attestation into this bundled SDK instance.
  // Only mark initialized on success or `appCheck/already-initialized`; propagate
  // all other failures so callers surface the error and can retry cleanly.
  if (!_appCheckInitialized && config.recaptchaSiteKey) {
    try {
      initializeAppCheck(app, {
        provider: new ReCaptchaEnterpriseProvider(config.recaptchaSiteKey),
        isTokenAutoRefreshEnabled: true,
      });
      _appCheckInitialized = true;
    } catch (err) {
      if (err && err.code === "appCheck/already-initialized") {
        _appCheckInitialized = true;
      } else {
        _appCheckInitialized = false;
        throw new Error(`App Check initialization failed: ${String(err?.message || err)}`);
      }
    }
  }

  _ai = getAI(app, { backend: new GoogleAIBackend() });
  _cachedConfigKey = key;
  return _ai;
}

async function checkChromePromptApiAvailability() {
  try {
    if (typeof globalThis.LanguageModel !== "undefined" && typeof globalThis.LanguageModel.availability === "function") {
      const avail = await globalThis.LanguageModel.availability();
      return {
        api: "LanguageModel",
        availability: String(avail),
      };
    }
    if (typeof globalThis.ai !== "undefined" && globalThis.ai.languageModel && typeof globalThis.ai.languageModel.capabilities === "function") {
      const caps = await globalThis.ai.languageModel.capabilities();
      return {
        api: "window.ai.languageModel",
        availability: String(caps?.available || "no"),
      };
    }
  } catch (err) {
    return { api: "error", availability: "unavailable", error: String(err) };
  }
  return { api: "none", availability: "unavailable" };
}

function mapAvailabilityToStatus(avail) {
  switch (avail) {
    case "available":
    case "readily":
      return "ready";
    case "downloadable":
    case "after-download":
      return "downloadAvailable";
    case "downloading":
      return "downloading";
    default:
      return "unsupported";
  }
}

globalThis.gardenHybridAi = {
  async checkCapability(configJson) {
    try {
      const config = typeof configJson === "string" ? JSON.parse(configJson) : (configJson || {});
      if (config.apiKey && config.projectId) {
        getOrInitAi(config);
      }
      const probe = await checkChromePromptApiAvailability();
      const status = mapAvailabilityToStatus(probe.availability);
      return JSON.stringify({
        status,
        platformLabel: "Web (Desktop Chrome + Firebase JS AI Logic)",
        modelIdentity: status === "ready" || status === "downloadAvailable"
          ? `Chrome Built-in Gemini Nano (${probe.api})`
          : null,
        message: status === "ready"
          ? "On-device Chrome model is ready for offline checklist generation."
          : status === "downloadAvailable"
          ? "On-device Chrome model can be prepared via 'Prepare offline AI'."
          : status === "downloading"
          ? "On-device Chrome model is currently downloading."
          : `On-device Prompt API not available in this browser (${probe.availability}). Cloud fallback remains available when online.`,
      });
    } catch (err) {
      return JSON.stringify({
        status: "error",
        platformLabel: "Web (Firebase JS AI Logic)",
        message: `Capability check failed: ${String(err)}`,
      });
    }
  },

  async prepareModel(configJson, onProgressCallback) {
    try {
      const config = typeof configJson === "string" ? JSON.parse(configJson) : (configJson || {});
      const ai = getOrInitAi(config);
      const model = getGenerativeModel(ai, {
        mode: InferenceMode.PREFER_ON_DEVICE,
        inCloudParams: { model: config.cloudModel || "gemini-3.8-flash" },
      });

      if (typeof model.initializeDeviceModel === "function") {
        await model.initializeDeviceModel((progress) => {
          if (typeof onProgressCallback === "function") {
            onProgressCallback(Number(progress || 0));
          }
        });
      } else if (typeof globalThis.LanguageModel !== "undefined" && typeof globalThis.LanguageModel.create === "function") {
        await globalThis.LanguageModel.create({
          monitor(m) {
            m.addEventListener("downloadprogress", (e) => {
              if (typeof onProgressCallback === "function") {
                const ratio = e.total ? e.loaded / e.total : (e.loaded || 0);
                onProgressCallback(Number(ratio));
              }
            });
          },
        });
      } else {
        return JSON.stringify({
          status: "unsupported",
          platformLabel: "Web (Firebase JS AI Logic)",
          message: "This browser does not expose on-device model preparation.",
        });
      }

      const probe = await checkChromePromptApiAvailability();
      const status = mapAvailabilityToStatus(probe.availability);
      return JSON.stringify({
        status,
        platformLabel: "Web (Desktop Chrome + Firebase JS AI Logic)",
        modelIdentity: status === "ready" ? `Chrome Built-in Gemini Nano (${probe.api})` : null,
        downloadProgress: status === "ready" ? 1.0 : 0.0,
        message: status === "ready"
          ? "On-device model prepared and ready."
          : `Model preparation finished with status: ${probe.availability}.`,
      });
    } catch (err) {
      return JSON.stringify({
        status: "error",
        platformLabel: "Web (Firebase JS AI Logic)",
        message: `Preparation failed: ${String(err)}`,
      });
    }
  },

  async generateChecklist(paramsJson) {
    const start = performance.now();
    let requestId = "";
    try {
      const params = typeof paramsJson === "string" ? JSON.parse(paramsJson) : paramsJson;
      requestId = params.requestId || `web_${Date.now()}`;
      _cancelled.delete(requestId);

      const ai = getOrInitAi(params.config || {});
      const mode = resolveMode(params.mode);
      const cloudModelName = params.cloudModel || "gemini-3.8-flash";

      const model = getGenerativeModel(ai, {
        mode,
        inCloudParams: { model: cloudModelName },
      });

      const result = await model.generateContent(params.prompt);
      const elapsedMs = Math.round(performance.now() - start);

      if (_cancelled.has(requestId)) {
        _cancelled.delete(requestId);
        return JSON.stringify({
          requestId,
          inferenceSource: "unknown",
          elapsedMs,
          errorCode: "CANCELLED",
          errorMessage: "Request cancelled by user.",
        });
      }

      const response = result.response;
      const text = typeof response.text === "function" ? response.text() : "";
      const rawSource = String(response.inferenceSource || "").toLowerCase();
      let inferenceSource = "unknown";
      if (rawSource.includes("on_device") || rawSource.includes("ondevice")) {
        inferenceSource = "onDevice";
      } else if (rawSource.includes("in_cloud") || rawSource.includes("cloud")) {
        inferenceSource = "inCloud";
      }

      return JSON.stringify({
        requestId,
        text: text.trim(),
        inferenceSource,
        elapsedMs,
        modelIdentity: inferenceSource === "onDevice"
          ? "Chrome Built-in Gemini Nano (Firebase AI Logic)"
          : cloudModelName,
      });
    } catch (err) {
      const elapsedMs = Math.round(performance.now() - start);
      return JSON.stringify({
        requestId,
        inferenceSource: "unknown",
        elapsedMs,
        errorCode: "INFERENCE_FAILED",
        errorMessage: String(err?.message || err),
      });
    }
  },

  cancel(requestId) {
    if (requestId) _cancelled.add(requestId);
  },
};
