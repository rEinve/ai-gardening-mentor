#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_ID="${FIREBASE_PROJECT_ID:-ai-gardening-mentor-dev}"
WEB_APP_ID="${FIREBASE_WEB_APP_ID:-1:1081285995650:web:46e916c18b9e12bf2b189b}"

echo "==> Building hybrid AI Web JS bundle..."
cd "${ROOT_DIR}/mobile/web_hybrid_src"
npm run build

echo "==> Fetching Firebase Web SDK configuration for ${PROJECT_ID}..."
SDK_JSON="$(firebase apps:sdkconfig web "${WEB_APP_ID}" --project "${PROJECT_ID}" --json 2>/dev/null || firebase apps:sdkconfig web "${WEB_APP_ID}" --project "${PROJECT_ID}")"
eval "$(
  SDK_JSON="${SDK_JSON}" node -e '
    const raw = process.env.SDK_JSON || "";
    const jsonStart = raw.indexOf("{");
    if (jsonStart === -1) process.exit(1);
    const parsed = JSON.parse(raw.slice(jsonStart));
    const cfg = parsed.result?.sdkConfig || parsed.sdkConfig || parsed;
    for (const [k, env] of [
      ["projectId", "FB_PROJECT_ID"],
      ["appId", "FB_APP_ID"],
      ["storageBucket", "FB_STORAGE_BUCKET"],
      ["apiKey", "FB_API_KEY"],
      ["authDomain", "FB_AUTH_DOMAIN"],
      ["messagingSenderId", "FB_MESSAGING_SENDER_ID"],
    ]) {
      if (!cfg[k]) {
        console.error("Missing Firebase Web SDK config field:", k);
        process.exit(1);
      }
      process.stdout.write(`export ${env}=${JSON.stringify(String(cfg[k]))}\n`);
    }
  '
)"

if [[ -z "${RECAPTCHA_SITE_KEY:-}" ]]; then
  ACCESS_TOKEN="$(gcloud auth print-access-token 2>/dev/null || true)"
  if [[ -n "${ACCESS_TOKEN}" ]]; then
    RECAPTCHA_SITE_KEY="$(
      curl -s \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        -H "x-goog-user-project: ${PROJECT_ID}" \
        "https://firebaseappcheck.googleapis.com/v1/projects/${PROJECT_ID}/apps/${WEB_APP_ID}/recaptchaEnterpriseConfig" \
      | node -e '
          let d = "";
          process.stdin.on("data", (c) => d += c);
          process.stdin.on("end", () => {
            try {
              const j = JSON.parse(d);
              if (j.siteKey) process.stdout.write(String(j.siteKey));
            } catch (_) {}
          });
        '
    )"
  fi
fi

if [[ -z "${RECAPTCHA_SITE_KEY:-}" ]]; then
  echo "ERROR: RECAPTCHA_SITE_KEY is empty and could not be read from Firebase App Check." >&2
  exit 1
fi

cd "${ROOT_DIR}/mobile"
FLUTTER_DEFINES=(
  "--dart-define=FIREBASE_PROJECT_ID=${FB_PROJECT_ID}"
  "--dart-define=FIREBASE_APP_ID=${FB_APP_ID}"
  "--dart-define=FIREBASE_STORAGE_BUCKET=${FB_STORAGE_BUCKET}"
  "--dart-define=FIREBASE_API_KEY=${FB_API_KEY}"
  "--dart-define=FIREBASE_AUTH_DOMAIN=${FB_AUTH_DOMAIN}"
  "--dart-define=FIREBASE_MESSAGING_SENDER_ID=${FB_MESSAGING_SENDER_ID}"
  "--dart-define=RECAPTCHA_SITE_KEY=${RECAPTCHA_SITE_KEY}"
)

echo "==> Building Flutter Web (--no-web-resources-cdn)..."
flutter build web --release --no-web-resources-cdn "${FLUTTER_DEFINES[@]}"

echo "==> Syncing build/web to backend/hosting-web and deploying Firebase Hosting..."
mkdir -p "${ROOT_DIR}/backend/hosting-web"
rm -rf "${ROOT_DIR}/backend/hosting-web/"*
cp -R "${ROOT_DIR}/mobile/build/web/"* "${ROOT_DIR}/backend/hosting-web/"

cd "${ROOT_DIR}/backend"
firebase deploy --only hosting --project "${PROJECT_ID}"
