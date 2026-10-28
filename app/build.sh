#!/usr/bin/env bash
# Compila CODM Control con la cadena manual validada (aapt2/javac/D8/7z/apksigner).
set -euo pipefail
cd "$(dirname "$0")"
ROOT="$(cd .. && pwd)"
SDK="$ROOT/herramientas/sdk/android-15"
PLATFORM="$ROOT/herramientas/sdk/android-35/android.jar"
JDK="${JDK_HOME:-C:/Program Files/Java/jdk-19}"
JAVAC="$JDK/bin/javac"
JAVA="java"
KEYTOOL="$JDK/bin/keytool"
SEVENZIP="C:/Program Files/7-Zip/7z.exe"
VERSION="1.5"
KS="${CODM_KS:-release.jks}"
ALIAS="codmcontrol"
PASS="${CODM_KS_PASS:?export CODM_KS_PASS}"

rm -rf build
mkdir -p build/compiled build/gen build/classes build/dex build/apk

echo "[1/6] aapt2 compile"
"$SDK/aapt2.exe" compile --dir res -o build/compiled/res.zip

echo "[2/6] aapt2 link"
"$SDK/aapt2.exe" link -o build/base.apk \
    -I "$PLATFORM" --manifest AndroidManifest.xml \
    --java build/gen --auto-add-overlay build/compiled/res.zip

echo "[3/6] javac"
"$JAVAC" -source 8 -target 8 -encoding UTF-8 -Xlint:-options \
    -bootclasspath "$PLATFORM" -d build/classes \
    $(find src -name '*.java') \
    build/gen/com/aj/codmcontrol/R.java

echo "[4/6] D8"
"$JAVA" -cp "$SDK/lib/d8.jar" com.android.tools.r8.D8 \
    --lib "$PLATFORM" --min-api 26 --output build/dex \
    $(find build/classes -name '*.class')

echo "[5/6] empaquetar y alinear"
cp build/base.apk build/unsigned.apk
(cd build/dex && "$SEVENZIP" a -tzip ../unsigned.apk classes.dex >/dev/null)
"$SDK/zipalign.exe" -f 4 build/unsigned.apk build/aligned.apk

echo "[6/6] firmar"
if [ ! -f "$KS" ]; then
    "$KEYTOOL" -genkeypair -keystore "$KS" -alias "$ALIAS" \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass "$PASS" -keypass "$PASS" \
        -dname "CN=CODM Control, OU=AJ, O=AJ, L=Local, C=CO"
fi
"$JAVA" -jar "$SDK/lib/apksigner.jar" sign \
    --ks "$KS" --ks-key-alias "$ALIAS" \
    --ks-pass "pass:$PASS" --key-pass "pass:$PASS" \
    --out "build/apk/codmcontrol-$VERSION.apk" build/aligned.apk
"$JAVA" -jar "$SDK/lib/apksigner.jar" verify --print-certs \
    "build/apk/codmcontrol-$VERSION.apk"
sha256sum "build/apk/codmcontrol-$VERSION.apk"
