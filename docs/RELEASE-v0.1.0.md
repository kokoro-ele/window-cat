# windowcat v0.1.0

First public release.

A small native macOS window companion. Drag the cat directly from the top menu bar onto an app window. It can walk, nap, and play with a ball or teaser.

- Drag a cat from the menu bar onto a window.
- Walk, nap, and play with a ball or teaser.
- English, Japanese and Simplified Chinese menus and installation guides.
- Basic placement and tracking require no Accessibility or Screen Recording permission.

## Install

Requires **macOS 13+ and Apple Silicon (M1 or later)**. Download `windowcat-macOS-arm64.zip`, unzip, move `windowcat.app` to Applications, and open it. Use the cat icon in the top menu bar; there is no main window.

This early build is ad-hoc signed and **not Apple-notarized**. If blocked, verify the source and use System Settings → Privacy & Security → Open Anyway for this app.

[English instructions](https://github.com/kokoro-ele/window-cat#install) · [中文教程](https://github.com/kokoro-ele/window-cat/blob/main/docs/README.zh-CN.md) · [日本語](https://github.com/kokoro-ele/window-cat/blob/main/docs/README.ja.md)

Core tests and controller diagnostics have been run. Physical menu-bar drag automation, multiple displays, Mission Control and Stage Manager are not fully verified. Please report reproduction steps in Issues.

Artwork: [Elthen](https://elthen.itch.io/2d-pixel-art-cat-sprites). Artwork is licensed separately and must not be redistributed as standalone assets.
