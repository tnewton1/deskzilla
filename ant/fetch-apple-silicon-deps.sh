#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SQLITE_DIR="$PROJECT_DIR/lib/sqlite4java"
SQLITE_VERSION="1.0.392"
SQLITE_JAR_URL="https://repo1.maven.org/maven2/com/almworks/sqlite4java/sqlite4java/${SQLITE_VERSION}/sqlite4java-${SQLITE_VERSION}.jar"
SQLITE_ARM_URL="https://repo1.maven.org/maven2/io/github/ganadist/sqlite4java/libsqlite4java-osx-aarch64/${SQLITE_VERSION}/libsqlite4java-osx-aarch64-${SQLITE_VERSION}.dylib"

mkdir -p "$SQLITE_DIR"

echo "Fetching sqlite4java ${SQLITE_VERSION} Java library..."
curl --fail --location --retry 3 --output "$SQLITE_DIR/sqlite4java.jar.download" "$SQLITE_JAR_URL"
mv "$SQLITE_DIR/sqlite4java.jar.download" "$SQLITE_DIR/sqlite4java.jar"

echo "Fetching sqlite4java ${SQLITE_VERSION} Apple Silicon native library..."
curl --fail --location --retry 3 --output "$SQLITE_DIR/libsqlite4java-osx-aarch64.dylib.download" "$SQLITE_ARM_URL"
mv "$SQLITE_DIR/libsqlite4java-osx-aarch64.dylib.download" "$SQLITE_DIR/libsqlite4java-osx-aarch64.dylib"
cp "$SQLITE_DIR/libsqlite4java-osx-aarch64.dylib" "$SQLITE_DIR/libsqlite4java-osx-arm64.dylib"

if command -v lipo >/dev/null 2>&1; then
  echo "Native library architectures:"
  lipo -archs "$SQLITE_DIR/libsqlite4java-osx-aarch64.dylib"
  if ! lipo -archs "$SQLITE_DIR/libsqlite4java-osx-aarch64.dylib" | grep -Eq '(^|[[:space:]])arm64($|[[:space:]])'; then
    echo "ERROR: downloaded SQLite library does not contain arm64." >&2
    exit 1
  fi
fi

echo "Apple Silicon SQLite dependencies are ready."
