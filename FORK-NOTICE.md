# Fork Notice

This repository is a modified fork of **Deskzilla**, originally developed by
ALM Works.

Original project information:

- Product: Deskzilla
- Original copyright: Copyright 2004-2020 ALM Works, Inc. / ALM Works Ltd.
- Original source repository: https://bitbucket.org/almworks/deskzilla/src/master/
- License: GNU General Public License, version 3 (GPLv3)

This fork retains the original Deskzilla copyright and license notices. The
original project and its authors are not responsible for changes made in this
fork.

## Changes in this fork

This fork adds and maintains native Apple Silicon macOS support, including:

- native arm64/aarch64 Java 8 build detection;
- creation of a self-contained `Deskzilla.app` bundle;
- bundled Apple Silicon Java runtime support;
- Apple Silicon `sqlite4java` native library support;
- compatibility with modern SQLite `PRAGMA index_list` results;
- macOS application icon packaging;
- Apple Silicon build documentation and automation; and
- an option to skip the historical test suite during packaging while retaining
  the ability to run it explicitly.

Additional changes made in this fork should be documented in Git history and,
when significant, in this file or the project README.

The application About dialog identifies ALM Works as the original developer and
credits Travis Newton for the Apple Silicon fork modifications. Binary macOS
bundles also include the GPL license, this fork notice, and `CREDITS.md`.

Deskzilla, ALM Works, Bugzilla, Java, Apple, macOS, and other names or marks
remain the property of their respective owners. This fork does not claim
ownership of the original Deskzilla project or its trademarks.
