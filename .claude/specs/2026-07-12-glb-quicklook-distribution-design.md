# GLB Quick Look 配布整備 設計書

日付: 2026-07-12
ステータス: 承認待ち
前提: MVP は完成・公開済み (https://github.com/trapple/glb-quicklook)

## 目的

Developer ID 署名 + 公証済みのバイナリを GitHub Release で配布し、Homebrew (自前 tap) で
インストールできるようにする。バージョン管理とリリース作業を `make release` 1 コマンドに自動化する。

## 要件

- Apple Developer Program 加入済み (Developer ID 署名・公証の正規ルート)
- リリースはローカル Mac で実行 (CI 化はスコープ外・将来候補)
- Homebrew は新規の自前 tap (`trapple/homebrew-tap`)。本家 homebrew-cask は狙わない
- 人間の作業は「バージョンを上げて commit → main へマージ」まで。以降は `make release` が全自動
- 開発ビルド (`make build` / `make install`) は現状の ad-hoc 署名のまま変えない

## バージョン管理

- **正は `project.yml` の `settings.base.MARKETING_VERSION`** (例: `"1.0.0"`, semver)
- 全ターゲット (app / appex) に反映される。`release.sh` は `grep` で取り出す
- リリースフロー:
  1. (人間) feature branch で `MARKETING_VERSION` を上げて commit → main へマージ
  2. (自動) `make release` → 前提チェック → ビルド → 署名 → 公証 → tag → GitHub Release → cask 更新
- 初回リリースは **v1.0.0**

## リリースパイプライン (`scripts/release.sh`、`make release` から呼ぶ)

### 前提チェック (1 つでも欠けたら手順を表示して即失敗 — Fail Fast)

1. カレント branch が main
2. working tree がクリーン
3. main が origin/main と一致 (push 済み)
4. tag `v{VERSION}` が未存在
5. keychain に Developer ID Application 証明書がある (`security find-identity` で自動検出)
6. 公証プロファイル `glb-quicklook-notary` が keychain にある
7. `gh` が認証済み

### ステップ

1. **ビルド**: 通常の Release ビルドに xcodebuild オーバーライドを追加
   - `CODE_SIGN_IDENTITY="Developer ID Application"` (証明書名は自動検出)
   - `ENABLE_HARDENED_RUNTIME=YES` (公証の必須条件)
   - `OTHER_CODE_SIGN_FLAGS=--timestamp` (セキュアタイムスタンプ)
   - `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO` (get-task-allow 除去。残ると公証で落ちる)
   - 同梱 GLTFKit2.framework は embed 時に自証明書で再署名されるため特別扱い不要
2. **公証**: zip 化 → `xcrun notarytool submit --keychain-profile glb-quicklook-notary --wait`
3. **staple**: `xcrun stapler staple GLBQuickLook.app` → staple 済み app を `ditto -c -k --keepParent` で
   `GLBQuickLook-{VERSION}.zip` に再 zip (これがリリース資産)
4. **tag & Release**: 注釈付き tag `v{VERSION}` を作成して push → `gh release create v{VERSION} <zip> --generate-notes`
5. **cask 更新**: `~/repos/github.com/trapple/homebrew-tap` (無ければ clone) の
   `Casks/glb-quicklook.rb` の `version` / `sha256` を書き換え → commit → push

## 1 回だけの手動セットアップ (release.sh の前提チェックが未設定を検出して案内)

1. Developer ID Application 証明書の作成 (Xcode → Settings → Accounts → Manage Certificates)
2. `xcrun notarytool store-credentials glb-quicklook-notary` で公証クレデンシャルを keychain に保存
   (App Store Connect API キー or Apple ID アプリ用パスワード。対話式のためユーザーが実行)

## Homebrew tap

- 新規 public リポジトリ `trapple/homebrew-tap`、`Casks/glb-quicklook.rb`
- cask 内容:
  - `version` / `sha256` (release.sh が更新)
  - `url "https://github.com/trapple/glb-quicklook/releases/download/v#{version}/GLBQuickLook-#{version}.zip"`
  - `app "GLBQuickLook.app"`
  - `depends_on macos: ">= :sequoia"` (macOS 15+)
  - `caveats`: 初回に一度アプリを起動すると Quick Look 拡張が登録される旨を案内
  - `zap trash`: `~/Library/Containers/jp.trapple.GLBQuickLook*`
- インストール方法: `brew install trapple/tap/glb-quicklook`

## エラーハンドリング

- release.sh は `set -euo pipefail`。全ステップ Fail Fast、リトライやフォールバックは持たない
- 公証の待機は `notarytool --wait` に任せる (タイムアウト管理を二重にしない)
- 公証 Invalid 時は `notarytool log` の取得コマンドを表示して終了

## テスト方針

- release.sh のユニットテストは持たない。**v1.0.0 の通しリリースが受け入れテスト**
- 受け入れ条件:
  1. `make release` が一度も手を止めずに完走する
  2. `spctl -a -vv /Applications/GLBQuickLook.app` が accepted (source=Notarized Developer ID) になる
  3. `brew install trapple/tap/glb-quicklook` でインストールでき、スペースキーでプレビューが動く
  4. GitHub Release v1.0.0 に staple 済み zip が添付されている

## スコープ外 (将来候補)

- GitHub Actions による CI リリース
- 本家 homebrew-cask への登録
- Sparkle 等による自動アップデート
