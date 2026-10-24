# Building windowcat

Requires macOS 13+, Swift 5.9 or later, and Xcode or Command Line Tools. The script builds for the current Mac architecture; published binaries are arm64. Install Command Line Tools with `xcode-select --install` if needed.

## Obtain the artwork first

1. Download **2D Pixel Art Cat Sprites** from [Elthen’s official page](https://elthen.itch.io/2d-pixel-art-cat-sprites), following the artist’s download flow and [license](https://www.patreon.com/elthen/posts/licensing-27430241).
2. Copy the original **256 × 320 PNG** sprite sheet to `Sources/WindowCat/Resources/Elthen/Cat.png`. Do not resize it or substitute the animated preview GIF.
3. This file is git-ignored because the artwork may not be redistributed on its own. Do not force-add it. Application builds include the licensed artwork as a product resource.

## Build and run

```sh
git clone https://github.com/kokoro-ele/window-cat.git
cd window-cat
# Place the licensed Cat.png as described above before building.
bash scripts/build.sh
open "dist/windowcat.app"
```

The build script generates a multi-resolution `.icns` icon from the original sitting cat, packages localized resources and applies an ad-hoc signature. It does not perform Developer ID signing or Apple notarization.

## Tests

```sh
swift test
```

Core tests do not need the artwork. To check the UI controller against a real external window after building, open a normal Finder or browser window and run:

```sh
"dist/windowcat.app/Contents/MacOS/WindowCat" --external-diagnostics /tmp/window-cat-check.json
```

This briefly places a cat on a visible external window, writes diagnostics and exits. It verifies the controller, panels and animation, not a physical mouse gesture. Diagnostic files can contain window geometry and app names; inspect them before sharing. Do not commit reports or your build cache.

## Release packaging

```sh
ditto -c -k --sequesterRsrc --keepParent "dist/windowcat.app" windowcat-macOS-arm64.zip
shasum -a 256 windowcat-macOS-arm64.zip
```

Use the architecture matching the machine that built the app in the filename. Never claim an arm64 build is universal. Verify the packaged app with `codesign --verify --strict "dist/windowcat.app"`.
