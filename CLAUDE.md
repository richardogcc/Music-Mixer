# Music Mixer — project conventions

This repo follows the shared standard used by all richardogcc macOS utility apps.

## License and language

- License: MIT, copyright line exactly `Copyright (c) 2026 richardogcc`.
- Everything is in English: README, UI strings, code comments, commit messages.

## Identity

- Bundle ID scheme: `com.richardogcc.<lowercased-app-name>` — here `com.richardogcc.musicmixer`.
- App name: `Music Mixer` (product/executable `MusicMixer`).

## Toolchain

- `Package.swift` uses `// swift-tools-version: 6.0`.
- Platforms: `.macOS("14.4")` — this app needs the CoreAudio process-tap API
  (`AudioHardwareCreateProcessTap`), introduced in macOS 14.4. The sibling-repo
  default is `.macOS(.v14)`; this repo is the documented exception.
- If Swift 6 language mode ever causes extensive concurrency errors, keep tools
  6.0 and add `swiftSettings: [.swiftLanguageMode(.v5)]` to the target instead
  of a large refactor.

## Versioning and releases

- `VERSION` holds the plain semver version; `CHANGELOG.md` follows the
  Keep a Changelog style (one `## <version> — <date>` entry per release).
- `Resources/Info.plist` is a template: `__VERSION__` is substituted from
  `VERSION` at build time by `scripts/build_app.sh`.
- `scripts/` layout:
  - `build_app.sh` — release swift build, assembles `build/Music Mixer.app`,
    injects the version into Info.plist, copies `Resources/AppIcon.icns`,
    ad-hoc signs with sandbox disabled.
  - `make_icon.swift` — regenerates the app icon (iconset into `build/`, then
    `Resources/AppIcon.icns`). The `.icns` is committed; the iconset is a
    regenerable intermediate and is not.
  - `release.sh` — builds the app, packages `dist/Music-Mixer-<VERSION>.dmg`
    via hdiutil, then creates the GitHub release (`gh release create`) with
    notes from the CHANGELOG entry.
- Releases are pushed manually from local by the owner. Never run the
  `gh release create` step yourself; building the DMG locally to verify is fine.

## Orchestrator

- `app-manifest.json` at the repo root describes the app (name, bundleId,
  description, repo, minMacOS, artifact pattern) for discovery by a future
  orchestrator app. Keep it in sync with VERSION/bundle changes.

## Git

- Never push. The owner pushes manually.
- Commit messages in English, ending with the trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`
