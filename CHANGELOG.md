# Changelog

## 1.1.0 — 2026-08-01

- Standardized About panel shared across the richardogcc utilities fleet.
- Bundle identifier is now `com.richardogcc.musicmixer` (was `com.musicmixer.app`). macOS treats this as a new app, so the audio-capture permission must be granted again after updating.
- License holder unified as `richardogcc`; repo standardized to the shared macOS utilities convention (Swift tools 6.0, `VERSION`/`CHANGELOG.md`, `scripts/`, `app-manifest.json` for the MLauncher orchestrator).
- Test target wired into the package — `swift test` now runs the test suite.
- Releases are distributed as a DMG (`Music-Mixer-<version>.dmg`) built by `scripts/release.sh`.

## 1.0.0 — 2026-08-01

Initial release.

- Per-application volume mixer for macOS, living in the menu bar (no Dock icon).
- Independent volume slider for every app currently playing audio, built on the CoreAudio process-tap API (`AudioHardwareCreateProcessTap`, macOS 14.4+).
- One-click mute per app without affecting others.
- Master system volume slider at the top of the popover.
- Persistent per-app volume levels across launches (keyed by bundle ID).
- Live updates: apps appear and disappear automatically as they start or stop playing audio.
