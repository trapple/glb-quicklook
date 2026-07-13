# GLB Quick Look

English | [日本語](README-ja.md)

A macOS Quick Look extension that previews .glb (glTF Binary) files with the spacebar in Finder.
Native implementation with RealityKit + GLTFKit2 — no WebView, no auto-rotation.

- Drag to orbit, pinch or two-finger scroll to zoom, right-drag (or Shift+drag) to pan
- Toggle dark ⇄ light background with the button in the top-right corner
- Broken files fall back to the standard Quick Look file info view
- Opening a .glb with the app (Finder's "Open With" / Cmd+O) shows it in a standalone viewer window
  - To make it the default app for double-click: select a .glb in Finder → "Get Info" → "Open with:" → choose GLBQuickLook → "Change All…"

## Install (Homebrew)

```bash
brew install trapple/tap/glb-quicklook
open /Applications/GLBQuickLook.app   # first time only: registers the Quick Look extension
```

## Build from source

Requirements: macOS 15+ / Xcode / xcodegen (`brew install xcodegen`)

```bash
make install   # fetch vendor deps → xcodegen → xcodebuild → copy to /Applications → register
```

If previews don't show up, try `make reset` (resets the qlmanage cache) and `killall Finder`.
Still nothing? Check the registration with `pluginkit -m | grep GLBQuickLook`.

## Development

```bash
make fixtures  # download sample .glb files (Khronos samples) into fixtures/
make test      # unit tests
make ql        # open a preview directly via qlmanage -p fixtures/Box.glb
```

## License

[MIT](LICENSE)
