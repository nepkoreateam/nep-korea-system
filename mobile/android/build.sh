#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DIR="$ROOT/mobile/android"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
test -n "$SDK" || { echo 'Android SDK not configured'; exit 1; }
TOOLS="$SDK/build-tools/35.0.0"
JAR="$SDK/platforms/android-35/android.jar"
test -f "$JAR" && test -x "$TOOLS/aapt2" || { echo 'Install Android SDK platform 35 and build-tools 35.0.0'; exit 1; }
OUT="$DIR/build"
rm -rf "$OUT"
mkdir -p "$OUT/res/drawable-nodpi" "$OUT/classes" "$OUT/dex" "$OUT/dist"
cp -R "$DIR/res/"* "$OUT/res/"
cp "$ROOT/icons/nep-v29-192.png" "$OUT/res/drawable-nodpi/nep_icon.png"
"$TOOLS/aapt2" compile --dir "$OUT/res" -o "$OUT/res.zip"
"$TOOLS/aapt2" link -o "$OUT/base.apk" -I "$JAR" --manifest "$DIR/AndroidManifest.xml" --min-sdk-version 26 --target-sdk-version 35 "$OUT/res.zip"
find "$DIR/src" -name '*.java' > "$OUT/sources.txt"
javac -encoding UTF-8 -source 8 -target 8 -classpath "$JAR" -d "$OUT/classes" @"$OUT/sources.txt"
(cd "$OUT/classes" && jar cf "$OUT/classes.jar" .)
"$TOOLS/d8" --release --min-api 26 --lib "$JAR" --output "$OUT/dex" "$OUT/classes.jar"
cp "$OUT/base.apk" "$OUT/unsigned-unaligned.apk"
(cd "$OUT/dex" && zip -q -j "$OUT/unsigned-unaligned.apk" classes.dex)
"$TOOLS/zipalign" -f -p 4 "$OUT/unsigned-unaligned.apk" "$OUT/dist/NEP-KOREA-unsigned.apk"
if [[ -n "${NEP_KEYSTORE:-}" ]]; then
  : "${NEP_KEY_ALIAS:?}" "${NEP_KEYSTORE_PASSWORD:?}" "${NEP_KEY_PASSWORD:?}"
  "$TOOLS/apksigner" sign --ks "$NEP_KEYSTORE" --ks-key-alias "$NEP_KEY_ALIAS" --ks-pass env:NEP_KEYSTORE_PASSWORD --key-pass env:NEP_KEY_PASSWORD --out "$OUT/dist/NEP-KOREA.apk" "$OUT/dist/NEP-KOREA-unsigned.apk"
else
  # Internal pilot only: a new ephemeral test signing key is generated for each build.
  keytool -genkeypair -keystore "$OUT/pilot.jks" -storetype JKS -storepass android -keypass android -alias neppilot -keyalg RSA -keysize 3072 -validity 3650 -dname "CN=NEP KOREA Internal Pilot,O=NEP KOREA,C=KR" >/dev/null
  "$TOOLS/apksigner" sign --ks "$OUT/pilot.jks" --ks-key-alias neppilot --ks-pass pass:android --key-pass pass:android --out "$OUT/dist/NEP-KOREA.apk" "$OUT/dist/NEP-KOREA-unsigned.apk"
fi
"$TOOLS/apksigner" verify --verbose --print-certs "$OUT/dist/NEP-KOREA.apk"
"$TOOLS/zipalign" -c -p 4 "$OUT/dist/NEP-KOREA.apk"
"$TOOLS/aapt" dump badging "$OUT/dist/NEP-KOREA.apk" | head -20
(cd "$OUT/dist" && sha256sum NEP-KOREA.apk > SHA256SUMS.txt)
# Allow the owner to re-sign the aligned unsigned package locally without disclosing a key.
cp "$TOOLS/lib/apksigner.jar" "$OUT/dist/apksigner.jar"
