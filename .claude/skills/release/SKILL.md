---
name: release
description: Release a new version of GLB Quick Look (bump MARKETING_VERSION → merge to main → make release). Use when user says "リリースして", "リリース", "release", "新しいバージョン出して", or "vX.Y.Z出して"
---

# GLB Quick Look リリース手順

バージョンの正は `project.yml` の `settings.base.MARKETING_VERSION` (semver)。
リリース本体は `make release` (`scripts/release.sh`) が全自動で行う。

## 手順

1. **バージョン決定** — ユーザーが指定しなければ semver で提案して確認する
   (機能追加 = minor、修正のみ = patch)。現在値: ！`grep -m1 'MARKETING_VERSION:' project.yml`
2. **feature branch でバージョンを上げる** (main 直コミット禁止)
   ```bash
   git -C <repo> switch -c release/vX.Y.Z
   # project.yml の MARKETING_VERSION を "X.Y.Z" に編集
   make build   # 生成 Info.plist が更新されるので必ずビルドを挟む
   git -C <repo> add project.yml GLBQuickLook/Info.plist PreviewExtension/Info.plist
   git -C <repo> commit -m "chore: vX.Y.Z"
   ```
   ※ 生成 Info.plist の add を忘れると release-check の「working tree がクリーンではない」で落ちる
3. **main へマージ & push**
   ```bash
   git -C <repo> switch main && git -C <repo> merge release/vX.Y.Z && git -C <repo> push
   ```
4. **前提チェック** — `make release-check` が ✅ になることを確認
5. **リリース実行** — `make release` を **run_in_background で起動**して完了を監視する
   (公証待ちが数分かかる。フォアグラウンドの timeout では足りないことがある)
6. **確認** — 完了ログの `🎉` 行と以下を確認:
   ```bash
   gh release view vX.Y.Z -R trapple/glb-quicklook
   ```
   tap の cask (`~/repos/github.com/trapple/homebrew-tap`) も自動 commit & push されている

## make release がやること (scripts/release.sh)

前提チェック (main / クリーン / origin一致 / tag未存在 / 証明書 / 公証プロファイル / gh認証)
→ Developer ID 署名ビルド (Hardened Runtime + timestamp, get-task-allow 除去)
→ 公証 (`notarytool --wait`) → staple → zip
→ `git tag vX.Y.Z` + GitHub Release (zip添付, --generate-notes)
→ tap の cask の version / sha256 を書き換えて push

## トラブルシューティング

- **公証で失敗**: `xcrun notarytool history --keychain-profile glb-quicklook-notary` で ID を確認し
  `xcrun notarytool log <ID> --keychain-profile glb-quicklook-notary`
- **前提チェックで証明書/プロファイルが無い** (新しい Mac 等の 1 回だけセットアップ):
  - 証明書: Xcode → Settings → Accounts → Manage Certificates → Developer ID Application
  - 公証: `xcrun notarytool store-credentials glb-quicklook-notary --apple-id <AppleID> --team-id 38BCPZ72CZ`
    (対話式のためユーザーのターミナルで実行してもらう。パスワードは account.apple.com のアプリ用パスワード)
- **リリース後に手元の拡張が動かない**: 開発版と brew 版が /Applications を取り合った可能性。
  `brew reinstall glb-quicklook` で公証版に戻し、登録が消えていたら:
  ```bash
  LSREG=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
  $LSREG -u <repo>/build/Build/Products/Release/GLBQuickLook.app
  $LSREG -f -R -trusted /Applications/GLBQuickLook.app
  killall pkd && sleep 3 && pluginkit -m | grep GLBQuickLook
  ```
