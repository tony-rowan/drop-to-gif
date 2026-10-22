# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A macOS 15+ SwiftUI app (a clone of mortenjust/droptogif): drop MP4/MOV files on the window and a GIF is written beside each original. It is a plain Swift package — there is no Xcode project, and no third-party dependencies.

## Commands

```sh
./scripts/build-app.sh && open "build/Drop to GIF.app"   # build the release .app and run it
swift build                                               # debug build only
swift test                                                # run all tests
swift test --filter rotatedVideo                          # run a single test (matches the test function name)
swiftlint lint --strict                                   # lint (warnings fail, as in CI)
swiftlint --fix                                           # auto-correct what it can
```

SwiftLint is pinned in `mise.toml`. CI (`.github/workflows/ci.yml`) runs the lint and `swift test` on every push, on `macos-26` runners.

`.swiftlint.yml` is an `only_rules` allow-list: correctness rules that catch outright mistakes, plus formatting rules that enforce one layout. Don't add taste-based rules (force unwraps, naming, complexity metrics) — the rule set is meant to have no false positives. The formatting rules mean a call or declaration that wraps puts every argument on its own line with the brackets on their own lines, rather than aligning continuation lines under the opening bracket; lines are at most 120 characters.

`scripts/build-app.sh` builds a universal (arm64 + x86_64) release binary, assembles `build/Drop to GIF.app` by hand from it plus `Support/Info.plist`, and ad-hoc signs it. Bundle metadata (identifier `gy.char.DropToGif`, version, minimum OS) lives only in `Support/Info.plist`, so change it there.

## Architecture

Two targets, split so the conversion logic is testable without the UI:

- **`GifKit`** (library) — `GifConverter.swift` holds everything that touches media: `canConvert` (UTType conforms to `.movie`), `outputURL` (picks `name.gif`, then `name 2.gif`, … to avoid overwriting), and `convert`, which samples frames with `AVAssetImageGenerator.images(for:)` and writes them through a `CGImageDestination`. Settings are `GifSettings` (fps, optional max width).
- **`DropToGif`** (executable) — the SwiftUI app. `ConversionQueue` is a `@MainActor @Observable` model that owns the jobs and processes them **one at a time**; `ContentView` binds directly to `queue.settings` and the job list; `JobRow` renders each job's state.

Non-obvious constraints worth knowing before editing:

- **Exact frame count.** The `CGImageDestination` is created for exactly `frameCount` images, so `convert` must add one image per requested time even when a frame fails to decode (it repeats the previous frame, or back-fills leading failures with the first good one). On any error or cancellation the partial GIF is deleted.
- **Rotation.** Output size is computed from `naturalSize.applying(preferredTransform)` with `appliesPreferredTrackTransform = true`, so portrait phone recordings stay upright and `maxWidth` applies to the displayed width.
- **Window sizing.** The window uses `.windowResizability(.contentSize)`, and a `ScrollView`'s minimum height is zero, so the job list is given an explicit height computed from `JobRow.height` (a fixed static) × visible rows (max 4). If you change a row's layout, keep `JobRow.height` accurate.
- **Concurrency.** Swift tools 6.0 means Swift 6 strict concurrency. The converter's progress callback is `@Sendable` and runs off the main actor; `ConversionQueue` hops back with `Task { @MainActor … }` and ignores progress for jobs no longer converting.

## Tests

Tests use Swift Testing (`@Suite`/`@Test`/`#expect`), not XCTest, and cover `GifKit` only. There are no fixture files: `makeVideo` in the test file synthesises short H.264 clips with `AVAssetWriter` into a per-test temporary folder, optionally with a transform to simulate rotated footage. Test names are behaviour sentences (e.g. "keeps portrait phone recordings upright") — follow that style.

## Conventions

User-facing strings and error messages use UK English (the bundle's development region is `en-GB`), e.g. `couldNotFinalise`.

## Git

Commit and push straight to `main` — this is a single-contributor repo, so don't create branches or pull requests.
