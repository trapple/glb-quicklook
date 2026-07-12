# GLB Quick Look

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

### リリース

1. feature branch で `project.yml` の `MARKETING_VERSION` を上げて commit → main へマージ & push
2. `make release-check` で前提を確認 (初回は Developer ID 証明書と `xcrun notarytool store-credentials glb-quicklook-notary` のセットアップが必要)
3. `make release` — 署名 → 公証 → GitHub Release → tap の cask 更新まで自動

- 設計: `.claude/specs/2026-07-12-glb-quicklook-design.md`
- 実装プラン (ハマりどころの記録込み): `.claude/plans/2026-07-12-glb-quicklook.md`

## 実装メモ (ハマりどころ)

- appex は **sandbox 必須** かつ **CFBundlePackageType: XPC!** — 欠けると pkd が登録を拒否し
  「機能拡張が見つかりません」になる。`log show --predicate 'process == "pkd"'` で理由が見える
- GLTFKit2 は SPM binaryTarget (動的 XCFramework) のため、XcodeGen では埋め込めず
  `vendor/` に直接取得してホストアプリへ embed している
- QL ホスト内では SwiftUI ジェスチャにピンチ / スクロールが配送されない。
  `NSEvent.addLocalMonitorForEvents` なら届く
- glTF 内蔵カメラ (Duck.glb 等) はロード後に除去しないとズームが効かなくなる
