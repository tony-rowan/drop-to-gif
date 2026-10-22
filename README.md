# Drop to GIF

A small macOS app: drop a video from Finder onto its window and it saves an animated GIF beside the original.

- Accepts MP4, MOV, M4V and any other video format AVFoundation can read
- Lets you pick the frame rate (10–25 fps) and maximum width (320–800 px or original)
- Converts several files one after another, with progress shown for each
- Keeps portrait phone recordings upright and never overwrites an existing GIF (`clip.gif`, then `clip 2.gif`, …)

It uses only system frameworks (AVFoundation and ImageIO), so it doesn't need ffmpeg or any other dependencies.

## Requirements

macOS 15 or later. You need Xcode (or the Swift 6 toolchain) to build it.

## Build and run

```sh
./scripts/build-app.sh          # builds "build/Drop to GIF.app" (universal, ad-hoc signed)
open "build/Drop to GIF.app"
```

To install it, copy `build/Drop to GIF.app` into `/Applications`.

During development:

```sh
swift run DropToGif   # run the app straight from the package
swift test            # convert generated MP4/MOV clips and check the GIFs
```

## Layout

- `Sources/GifKit` holds the conversion engine (`GifConverter`)
- `Sources/DropToGif` holds the SwiftUI app: drop zone, settings and the conversion queue
- `Support/Info.plist` is the bundle metadata used by the build script
