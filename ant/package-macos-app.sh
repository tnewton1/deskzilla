#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$PROJECT_DIR/build/.dist/deskzilla"
APP_DIR="$PROJECT_DIR/build/.dist/Deskzilla.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
PLUGINS="$CONTENTS/PlugIns"
APP_PAYLOAD="$RESOURCES/deskzilla"
BUNDLED_JRE="$PLUGINS/jre"
ICON_FILE="$RESOURCES/Deskzilla.icns"
SOURCE_ICON="$PROJECT_DIR/env/macos/Deskzilla.icns"

if [[ ! -f "$DIST_DIR/deskzilla.jar" ]]; then
  echo "ERROR: Deskzilla distribution was not found at $DIST_DIR" >&2
  echo "Run build-apple-silicon.sh first." >&2
  exit 1
fi

if [[ -z "${JDK8_HOME:-}" || ! -x "$JDK8_HOME/bin/java" || ! -d "$JDK8_HOME/jre" ]]; then
  echo "ERROR: JDK8_HOME must point to the Apple Silicon Java 8 JDK used for the build." >&2
  exit 1
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$APP_PAYLOAD" "$PLUGINS"
cp -R "$DIST_DIR"/. "$APP_PAYLOAD"/

# Install a proper macOS application icon. Prefer a source-controlled icon.
# If the source icon is missing, import the original icon from an existing
# Deskzilla installation and persist it into env/macos/Deskzilla.icns so it can
# be committed to the fork and reused by future builds. DESKZILLA_ICON may be
# used to supply an explicit .icns file.
mkdir -p "$(dirname "$SOURCE_ICON")"

persist_icon() {
  local source="$1"

  cp "$source" "$ICON_FILE"

  if [[ "${PERSIST_DESKZILLA_ICON:-1}" != "0" ]]; then
    if [[ "$source" != "$SOURCE_ICON" ]]; then
      cp "$source" "$SOURCE_ICON"
      echo "Saved Deskzilla icon to source tree: $SOURCE_ICON"
    fi
  fi
}

copy_existing_icon() {
  local candidate icon_name icon_path

  if [[ -f "$SOURCE_ICON" ]]; then
    cp "$SOURCE_ICON" "$ICON_FILE"
    echo "Using Deskzilla icon from source tree: $SOURCE_ICON"
    return 0
  fi

  if [[ -n "${DESKZILLA_ICON:-}" && -f "$DESKZILLA_ICON" ]]; then
    persist_icon "$DESKZILLA_ICON"
    echo "Using Deskzilla icon: $DESKZILLA_ICON"
    return 0
  fi

  for candidate in \
    "/Applications/Deskzilla.app" \
    "$HOME/Applications/Deskzilla.app"; do
    [[ -d "$candidate/Contents/Resources" ]] || continue

    icon_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$candidate/Contents/Info.plist" 2>/dev/null || true)"
    if [[ -n "$icon_name" ]]; then
      [[ "$icon_name" == *.icns ]] || icon_name="$icon_name.icns"
      icon_path="$candidate/Contents/Resources/$icon_name"
      if [[ -f "$icon_path" ]]; then
        persist_icon "$icon_path"
        echo "Using original Deskzilla icon from: $icon_path"
        return 0
      fi
    fi

    icon_path="$(find "$candidate/Contents/Resources" -maxdepth 1 -type f -name '*.icns' -print -quit 2>/dev/null || true)"
    if [[ -n "$icon_path" && -f "$icon_path" ]]; then
      persist_icon "$icon_path"
      echo "Using original Deskzilla icon from: $icon_path"
      return 0
    fi
  done

  return 1
}

create_fallback_icon() {
  local source_png="$PROJECT_DIR/env/distimage.deskzilla/deskzilla.png"
  local iconset="$PROJECT_DIR/build/.deskzilla.iconset"

  if [[ ! -f "$source_png" ]]; then
    echo "WARNING: no Deskzilla icon source was found; app will use the generic icon." >&2
    return 1
  fi

  rm -rf "$iconset"
  mkdir -p "$iconset"

  # Build every size macOS expects. This source image is small, so this is a
  # fallback only; the original .icns from Deskzilla.app is preferred.
  sips -z 16 16     "$source_png" --out "$iconset/icon_16x16.png" >/dev/null
  sips -z 32 32     "$source_png" --out "$iconset/icon_16x16@2x.png" >/dev/null
  sips -z 32 32     "$source_png" --out "$iconset/icon_32x32.png" >/dev/null
  sips -z 64 64     "$source_png" --out "$iconset/icon_32x32@2x.png" >/dev/null
  sips -z 128 128   "$source_png" --out "$iconset/icon_128x128.png" >/dev/null
  sips -z 256 256   "$source_png" --out "$iconset/icon_128x128@2x.png" >/dev/null
  sips -z 256 256   "$source_png" --out "$iconset/icon_256x256.png" >/dev/null
  sips -z 512 512   "$source_png" --out "$iconset/icon_256x256@2x.png" >/dev/null
  sips -z 512 512   "$source_png" --out "$iconset/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$source_png" --out "$iconset/icon_512x512@2x.png" >/dev/null

  iconutil -c icns "$iconset" -o "$SOURCE_ICON"
  rm -rf "$iconset"
  cp "$SOURCE_ICON" "$ICON_FILE"
  echo "Generated fallback Deskzilla icon and saved it to source tree: $SOURCE_ICON"
}

copy_existing_icon || create_fallback_icon || true

# Bundle the JRE so Deskzilla does not accidentally launch through an old Intel Java install.
if command -v ditto >/dev/null 2>&1; then
  ditto "$JDK8_HOME/jre" "$BUNDLED_JRE"
else
  cp -R "$JDK8_HOME/jre" "$BUNDLED_JRE"
fi

cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>English</string>
  <key>CFBundleDisplayName</key>
  <string>Deskzilla</string>
  <key>CFBundleExecutable</key>
  <string>Deskzilla</string>
  <key>CFBundleIdentifier</key>
  <string>com.almworks.deskzilla.community</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>Deskzilla.icns</string>
  <key>CFBundleName</key>
  <string>Deskzilla</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>3.2.2</string>
  <key>CFBundleVersion</key>
  <string>3.2.2</string>
  <key>LSMinimumSystemVersion</key>
  <string>11.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

cat > "$MACOS/Deskzilla" <<'LAUNCHER'
#!/bin/bash
set -euo pipefail

CONTENTS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_HOME="$CONTENTS_DIR/Resources/deskzilla"
JAVA="$CONTENTS_DIR/PlugIns/jre/bin/java"

if [[ ! -x "$JAVA" ]]; then
  osascript -e 'display alert "Deskzilla runtime is missing" message "The bundled Apple Silicon Java 8 runtime could not be found. Rebuild Deskzilla.app." as critical'
  exit 1
fi

JAVA_ARCH="$($JAVA -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*os.arch = //p' | head -n 1)"
case "$JAVA_ARCH" in
  aarch64|arm64) ;;
  *)
    osascript -e 'display alert "Incorrect Deskzilla runtime" message "The bundled Java runtime is not an Apple Silicon build. Rebuild Deskzilla.app with an arm64/aarch64 Java 8 JDK." as critical'
    exit 1
    ;;
esac

cd "$APP_HOME"
exec /usr/bin/arch -arm64 "$JAVA" \
  -Xdock:name=Deskzilla \
  -Xmx600m \
  -Dapple.laf.useScreenMenuBar=true \
  -Dsqlite4java.library.path="$APP_HOME/lib" \
  -jar "$APP_HOME/deskzilla.jar" "$@"
LAUNCHER
chmod +x "$MACOS/Deskzilla"

# Ad-hoc sign the locally built app so macOS sees a sealed bundle.
if command -v codesign >/dev/null 2>&1; then
  if ! codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1; then
    echo "WARNING: ad-hoc code signing failed; the app bundle was still created." >&2
  fi
fi

# Bump the bundle timestamp so Finder/Dock notice icon changes promptly.
/usr/bin/touch "$APP_DIR"

echo "Created $APP_DIR"
