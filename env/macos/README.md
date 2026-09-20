# macOS application resources

`Deskzilla.icns` is the source-controlled application icon used by the native
macOS application bundle.

If `Deskzilla.icns` is missing, `ant/package-macos-app.sh` tries to import the
original icon from an existing `/Applications/Deskzilla.app` or
`~/Applications/Deskzilla.app`. When it succeeds, it writes the imported icon
to this directory so it can be committed to the fork and reused by future
builds without the legacy Intel application being installed.

You can also provide an icon explicitly for one build:

```bash
DESKZILLA_ICON=/path/to/Deskzilla.icns ./build-apple-silicon.sh
```

When an explicit icon is supplied, it is copied into this directory as the
source icon unless `PERSIST_DESKZILLA_ICON=0` is set.

After the first successful import, commit `env/macos/Deskzilla.icns` to the
repository. The original Deskzilla artwork remains attributable to the original
Deskzilla project/ALM Works. See `LICENSE`, `FORK-NOTICE.md`, and `CREDITS.md`.
