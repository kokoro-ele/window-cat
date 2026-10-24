# windowcat

A tiny pixel cat for your Mac windows. Drag it from the menu bar onto a window, then let it walk, nap, or play.

**macOS 13+ · Apple Silicon download · English / 日本語 / 简体中文 · Native Swift + AppKit**

[Download the latest release](https://github.com/kokoro-ele/window-cat/releases/latest) · [中文安装教程](docs/README.zh-CN.md) · [日本語ガイド](docs/README.ja.md) · [Build from source](docs/BUILD.md)

## Install

1. Download `windowcat-macOS-arm64.zip` from **Releases**. The prebuilt app supports Apple Silicon (M1 or later). Intel users can build from source.
2. Unzip and drag **windowcat.app** into **Applications**.
3. Open the app. Look for the cat in the **top macOS menu bar**. It does not open a main window or show a Dock icon.
4. This early release is ad-hoc signed, **not Apple-notarized**. If macOS blocks it, first verify that you downloaded it from this repository, then open **System Settings → Privacy & Security → Open Anyway** after attempting to launch. Follow the macOS confirmation. Do not disable Gatekeeper globally. On a managed Mac, your administrator may prohibit this.


## Give a window a cat

1. Open a normal app window, such as Finder or a browser.
2. **Hold the menu-bar cat icon and drag it onto that window.** A green outline marks the destination.
3. Release. The cat stays attached to that window and walks along its edges.
4. Click the menu-bar icon without dragging to open the menu. Choose a cat under the companions menu, then choose a behavior: walk, ball, teaser, or nap.

You can add one cat per window, up to 12. Dropping onto the same window selects its existing cat. Switching apps does not change the target. Cats follow window movement and resizing, hide when the window is minimized or unavailable, and disappear when it closes. Placement is not restored after quitting. Overlays let mouse clicks pass through.

The menu also provides pause, speed, automatic naps, removal, language selection, and quit. Language changes apply immediately and are saved. There is no sidebar or demo window in normal use.

## Permissions and privacy

Basic placement and tracking need **neither Accessibility nor Screen Recording permission**. The app reads window IDs, process IDs and geometry through macOS APIs. It does not capture screenshots or read document contents. The runtime has no network calls, account, analytics, or third-party code dependencies.

“Enhanced window tracking (optional)” enables Accessibility event notifications. If you choose it, grant access to the current app copy in System Settings → Privacy & Security → Accessibility and restart the app. Without it, geometry polling remains available.

## Troubleshooting

- **No main window:** expected; use the cat at the top of the screen. If the menu bar is crowded or hidden by a notch, make room for its icon.
- **No cat yet:** opening the app does not place a cat automatically. Drag from the menu bar to a visible, normal app window.
- **Cat disappears:** bring its window back into view. Minimized windows, closed windows and occluded edges do not show the cat.
- **Download cannot be opened:** use the per-app macOS approval above; this release has no Developer ID notarization. Do not change system-wide security settings.
- **Special window behavior:** Mission Control, Stage Manager, fullscreen windows, multiple displays and system overlays have compatibility limits. Please [open an issue](https://github.com/kokoro-ele/window-cat/issues) with macOS version, Mac model and reproduction steps; avoid posting private window contents.

## Implementation and verification

AppKit overlays, cached PNG frames and a shared 30 Hz movement clock keep the implementation small. Visible sleeping cats reduce animation updates to 1 Hz. Pausing, locking and display sleep stop updates. Window polling is normally 1 Hz and increases while dragging windows; optional AX notifications improve responsiveness.

29 core tests cover geometry, movement, window selection, occlusion and localization. Controller integration diagnostics check placement on a real external window, panel visibility and advancing rendered animation. They do **not** automate the complete physical menu-bar drag gesture. Multi-monitor and system UI edge cases are not fully verified.

See [BUILD.md](docs/BUILD.md) for source setup and diagnostics.

## Artwork and source rights

Cat artwork is by [Elthen](https://elthen.itch.io/2d-pixel-art-cat-sprites), under [Elthen’s Common Sense License 1.0](https://www.patreon.com/elthen/posts/licensing-27430241). It is included in the application as part of the product, but **the sprite sheet and generated icon are excluded from this source repository**. Obtain artwork directly from the artist to build locally. Do not extract and redistribute it as an asset pack. See [attribution](Sources/WindowCat/Resources/Elthen/ATTRIBUTION.txt).

The repository publishes source for inspection and local builds. No separate open-source license has been granted for the application code yet; the artwork has its own terms.
