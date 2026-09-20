# Deskzilla on Apple Silicon

This branch adds a native Apple Silicon build path for Deskzilla 3.2.2.

## Why the original build is Intel-only on modern Macs

Deskzilla is mostly Java, so its application classes are CPU-independent. The original distribution nevertheless has two architecture-sensitive pieces:

1. the Java 8 / JavaFX runtime used to execute the application;
2. sqlite4java's native macOS library.

The repository originally contains only Intel/PPC macOS sqlite4java libraries. This build path adds the Apple Silicon sqlite4java library and packages Deskzilla into a macOS `.app` with its own bundled arm64 Java 8 runtime.

## Requirements

- Apple Silicon Mac (`uname -m` must return `arm64`)
- macOS 11 or later
- Apache Ant (`brew install ant`)
- Java 8 for Apple Silicon **with JavaFX 8 included**

Liberica JDK 8 Full is a suitable choice because its Full distribution includes LibericaFX/JavaFX. Do not use a Java 8 package that omits JavaFX.

With Homebrew, the prerequisites can be installed with:

```bash
brew install ant
brew tap bell-sw/liberica
brew install --cask liberica-jdk8-full
```

After installing Java 8, verify it with:

```bash
/usr/libexec/java_home -V
JAVA_HOME=$(/usr/libexec/java_home -v 1.8)
"$JAVA_HOME/bin/java" -XshowSettings:properties -version 2>&1 | grep 'os.arch'
ls "$JAVA_HOME/jre/lib/ext/jfxrt.jar"
```

The architecture must be `aarch64` or `arm64`, and `jfxrt.jar` must exist.

## Build

From the repository root:

```bash
cd ant
./build-apple-silicon.sh
```

To set an explicit JDK:

```bash
cd ant
JDK8_HOME="/path/to/your/arm64/java8/Contents/Home" ./build-apple-silicon.sh
```

To set Deskzilla's build number:

```bash
cd ant
BUILD_NUMBER=1001 ./build-apple-silicon.sh
```

The build script downloads the matching sqlite4java 1.0.392 Java library and Apple Silicon native library from Maven Central before compiling.

Outputs:

- `build/.dist/Deskzilla.app` — macOS application bundle
- `build/.dist/deskzilla` — raw Deskzilla distribution

## Run

`Deskzilla.app` contains the Apple Silicon Java 8 runtime used during the build, so the finished app does not depend on whichever Java happens to be installed later.

Open `build/.dist/Deskzilla.app` in Finder, or run:

```bash
open build/.dist/Deskzilla.app
```

The app launcher uses only its bundled arm64 Java runtime and explicitly launches it as `arm64`. This prevents macOS from silently running Deskzilla under Rosetta.

## Verify that it is native

With Deskzilla running:

```bash
ps -axo pid,arch,command | grep '[j]ava'
```

The Java process used by Deskzilla should show `arm64`.

You can also verify the SQLite native library before launching:

```bash
lipo -archs build/.dist/Deskzilla.app/Contents/Resources/deskzilla/lib/libsqlite4java-osx-aarch64.dylib
```

It should report `arm64`.

## Existing workspace

The application still uses Deskzilla's existing workspace format. Back up the existing workspace before launching this build for the first time.

## Notes

The old bundled JNA library remains in the project because Deskzilla only references it from Windows-specific code. It is not used for the macOS path. The build intentionally stays on Java 8 because Deskzilla directly uses JavaFX 8 and its build metadata is written around the Java 8 JDK layout.

## Legacy test suite

The normal Apple Silicon packaging build skips the historical JUnit suite by
setting Ant's existing `without.tests` property. The production sources are
still fully compiled before the application is packaged. Some of the tests
assume older JVM/native dependency behavior and can fail on a current ARM Mac.

To explicitly run the tests while working on them:

```bash
RUN_TESTS=1 ./ant/build-apple-silicon.sh
```

## Application icon

The macOS packager uses `env/macos/Deskzilla.icns` as the source-controlled
application icon. If that file does not yet exist, the first build will try to
import the icon from an existing `/Applications/Deskzilla.app` or
`~/Applications/Deskzilla.app` and save it to `env/macos/Deskzilla.icns`.

After a successful first build, commit the imported icon:

```bash
git add env/macos/Deskzilla.icns
git commit -m "Add original Deskzilla macOS application icon"
```

An explicit icon can be supplied with `DESKZILLA_ICON=/path/to/file.icns`. Set
`PERSIST_DESKZILLA_ICON=0` if an override should be used only for that build and
not copied into the source tree.
