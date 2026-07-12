# GLB Quick Look

[English](README.md) | 日本語

.glb (glTF Binary) を Finder のスペースキーでプレビューする macOS Quick Look 拡張。
RealityKit + GLTFKit2 によるネイティブ実装 (WebView なし・自動回転なし)。

- ドラッグで回転、ピンチ / 2本指スクロールでズーム
- 右上のボタンで背景色をダーク ⇄ ライト切替
- 壊れたファイルは Quick Look 標準のファイル情報表示にフォールバック

## インストール (Homebrew)

```bash
brew install trapple/tap/glb-quicklook
open /Applications/GLBQuickLook.app   # 初回のみ: Quick Look 拡張の登録
```

## ソースからビルド

要件: macOS 15+ / Xcode / xcodegen (`brew install xcodegen`)

```bash
make install   # vendor取得 → xcodegen → xcodebuild → /Applications に配置 → 拡張登録
```

プレビューが出ないときは `make reset` (qlmanage キャッシュリセット) と `killall Finder`。
それでも出ないときは `pluginkit -m | grep GLBQuickLook` で登録を確認する。

## 開発

```bash
make fixtures  # テスト用 .glb (Khronos サンプル) を fixtures/ に取得
make test      # ユニットテスト
make ql        # qlmanage -p fixtures/Box.glb で直接プレビュー起動
```

## ライセンス

[MIT](LICENSE)
