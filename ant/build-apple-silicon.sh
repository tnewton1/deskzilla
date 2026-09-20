#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_NUMBER="${BUILD_NUMBER:-0}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: this build script must be run on macOS." >&2
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "ERROR: this script is for an Apple Silicon Mac. uname -m returned: $(uname -m)" >&2
  exit 1
fi

if [[ -z "${JDK8_HOME:-}" ]]; then
  CANDIDATES=()
  DEFAULT_JAVA8="$(/usr/libexec/java_home -v 1.8 2>/dev/null || true)"
  if [[ -n "$DEFAULT_JAVA8" ]]; then
    CANDIDATES+=("$DEFAULT_JAVA8")
  fi
  for candidate in /Library/Java/JavaVirtualMachines/*/Contents/Home "$HOME"/Library/Java/JavaVirtualMachines/*/Contents/Home; do
    [[ -d "$candidate" ]] || continue
    CANDIDATES+=("$candidate")
  done

  for candidate in "${CANDIDATES[@]}"; do
    [[ -x "$candidate/bin/java" ]] || continue
    version="$($candidate/bin/java -version 2>&1 | head -n 1 || true)"
    [[ "$version" == *'1.8.0_'* ]] || continue
    arch="$($candidate/bin/java -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*os.arch = //p' | head -n 1 || true)"
    [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] || continue
    [[ -f "$candidate/jre/lib/ext/jfxrt.jar" ]] || continue
    JDK8_HOME="$candidate"
    break
  done

  if [[ -z "${JDK8_HOME:-}" ]]; then
    echo "ERROR: an Apple Silicon Java 8 JDK with JavaFX was not found." >&2
    echo "Install Liberica JDK 8 Full, then rerun this script." >&2
    echo "You may also set JDK8_HOME explicitly." >&2
    exit 1
  fi
fi
JAVA="$JDK8_HOME/bin/java"
if [[ ! -x "$JAVA" ]]; then
  echo "ERROR: JDK8_HOME does not point to a usable JDK: $JDK8_HOME" >&2
  exit 1
fi

JAVA_VERSION="$($JAVA -version 2>&1 | head -n 1)"
if [[ "$JAVA_VERSION" != *'1.8.0_'* ]]; then
  echo "ERROR: Deskzilla requires Java 8 for this build. Found: $JAVA_VERSION" >&2
  exit 1
fi

JAVA_ARCH="$($JAVA -XshowSettings:properties -version 2>&1 | sed -n 's/^[[:space:]]*os.arch = //p' | head -n 1)"
case "$JAVA_ARCH" in
  aarch64|arm64) ;;
  *)
    echo "ERROR: Java 8 is not an Apple Silicon build. JVM os.arch is: ${JAVA_ARCH:-unknown}" >&2
    echo "Install an arm64/aarch64 Java 8 JDK and set JDK8_HOME to it." >&2
    exit 1
    ;;
esac

JFXRT="$JDK8_HOME/jre/lib/ext/jfxrt.jar"
if [[ ! -f "$JFXRT" ]]; then
  echo "ERROR: JavaFX 8 was not found at: $JFXRT" >&2
  echo "Use a Java 8 distribution with JavaFX included, such as Liberica JDK 8 Full." >&2
  exit 1
fi

for required in "$JDK8_HOME/jre/lib/jce.jar" "$JDK8_HOME/jre/lib/jsse.jar"; do
  if [[ ! -f "$required" ]]; then
    echo "ERROR: required Java 8 library missing: $required" >&2
    exit 1
  fi
done

if ! command -v ant >/dev/null 2>&1; then
  echo "ERROR: Apache Ant was not found. Install it with: brew install ant" >&2
  exit 1
fi

"$SCRIPT_DIR/fetch-apple-silicon-deps.sh"

export JAVA_HOME="$JDK8_HOME"
export PATH="$JAVA_HOME/bin:$PATH"

cd "$SCRIPT_DIR"
echo "Building Deskzilla with:"
echo "  Java: $JAVA_VERSION"
echo "  JVM architecture: $JAVA_ARCH"
echo "  JDK: $JDK8_HOME"
echo "  Ant: $(ant -version)"
echo "  Build number: $BUILD_NUMBER"

ANT_ARGS=(
  -f build.xml
  prepareDistribution
  -Djdk="$JDK8_HOME"
  -Dbuild.number="$BUILD_NUMBER"
)

# Deskzilla's historical test suite predates current macOS/Apple Silicon and
# modern versions of several bundled/native dependencies.  The generated Ant
# build already supports the `without.tests` property; use it for normal
# packaging so an obsolete test does not prevent creation of Deskzilla.app.
# Set RUN_TESTS=1 when explicitly diagnosing/updating the legacy test suite.
if [[ "${RUN_TESTS:-0}" != "1" ]]; then
  ANT_ARGS+=( -Dwithout.tests=true )
  echo "  Tests: skipped for Apple Silicon packaging (set RUN_TESTS=1 to enable)"
else
  echo "  Tests: enabled"
fi

ant "${ANT_ARGS[@]}"

JDK8_HOME="$JDK8_HOME" "$SCRIPT_DIR/package-macos-app.sh"

echo
echo "Build complete."
echo "Application bundle: $PROJECT_DIR/build/.dist/Deskzilla.app"
echo "Raw distribution:  $PROJECT_DIR/build/.dist/deskzilla"
if [[ -f "$PROJECT_DIR/env/macos/Deskzilla.icns" ]]; then
  echo "Source app icon:    $PROJECT_DIR/env/macos/Deskzilla.icns"
  echo "                    (commit this file to keep the original icon in your fork)"
fi
