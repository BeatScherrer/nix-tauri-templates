default:
  just --list

dev:
  cargo tauri dev

android-dev:
  cargo tauri android dev

build-android:
  cargo tauri android build

build-android-apk:
  cargo tauri android build --apk

# Android App Bundle (AAB)
build-android-google-play:
  cargo tauri android build --aab

create-apk-key:
  keytool -genkeypair -v \
    -keystore tauri-dev.jks \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -alias tauri-dev

# Sign an APK (required for installation)
sign-apk apk_path:
  apksigner sign --ks tauri-dev.jks \
    --ks-key-alias tauri-dev \
    --ks-pass pass:123456 \
    --key-pass pass:123456 \
    --out app-signed.apk \
    {{apk_path}}

# Install an APK
install-apk apk_path:
  sudo adb install {{apk_path}}

# convenient way to just install on an android device
update-android:
  #!/usr/bin/env bash
  if [[ "${EUID}" -ne 0 ]]; then
    echo >&2 "requires sudo to update the android app, elevating privilege"
    sudo -E "$0" "$@"
  fi

  APK="$(find . -name "app-universal-release-unsigned.apk")"
  just build-android-apk
  just sign-apk "$APK"
  just install-apk app-signed.apk

