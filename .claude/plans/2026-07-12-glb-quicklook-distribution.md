# GLB Quick Look 配布整備 実装プラン

> **実装者向け:** このプランは subagent-driven-development (推奨) または手動実行で消化する。step は `- [ ]` チェックボックスで track する。

**Goal:** Developer ID 署名 + 公証済み zip を GitHub Release で配布し、自前 Homebrew tap でインストール可能にする。リリースは `make release` 1 コマンド。

**Architecture:** バージョンの正は `project.yml` の `MARKETING_VERSION`。`scripts/release.sh` が前提チェック → 署名ビルド → 公証/staple → tag/GitHub Release → tap の cask 更新を直列実行する。開発ビルド (ad-hoc) は変更しない。

**Tech Stack:** bash / xcodebuild / notarytool / stapler / gh CLI / Homebrew cask

## Global Constraints

### Spec 由来 (spec から逐語コピー)

- バージョンの正は `project.yml` の `settings.base.MARKETING_VERSION` (semver)。初回リリースは **v1.0.0**
- 開発ビルド (`make build` / `make install`) は現状の ad-hoc 署名のまま変えない
- リリースビルドのオーバーライド: `CODE_SIGN_IDENTITY="Developer ID Application"` (自動検出) / `ENABLE_HARDENED_RUNTIME=YES` / `OTHER_CODE_SIGN_FLAGS=--timestamp` / `CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO`
- 公証プロファイル名: `glb-quicklook-notary`。公証は `notarytool submit --wait`、成功後 `stapler staple`、staple 済み app を zip 化してリリース資産に
- 前提チェック 7 項目 (main / クリーン / origin一致 / tag未存在 / 証明書 / 公証プロファイル / gh認証)。欠けたら手順を表示して即失敗
- tap: `trapple/homebrew-tap` (public) の `Casks/glb-quicklook.rb`。`depends_on macos: ">= :sequoia"`、caveats で初回起動を案内、zap でコンテナ掃除
- release.sh は `set -euo pipefail`。リトライ・フォールバックなし。公証待機は `--wait` に任せる (二重タイムアウト管理をしない)
- 受け入れ条件: ①make release 完走 ②`spctl -a -vv` が accepted (Notarized Developer ID) ③`brew install trapple/tap/glb-quicklook` で動く ④Release v1.0.0 に staple 済み zip

### PJ 恒久ルール (CLAUDE.md / `.claude/rules/` 由来)

- git 操作は `git -C <dir>` / gh は `-R <owner/repo>` (スクリプト内も同様)
- 外部プロセスには timeout を意識する ※ 局所例外: notarytool の `--wait` は spec が「二重タイムアウト管理をしない」と定めるため release.sh 内では無制限。呼び出し側 (Bashツール) で run_in_background + 監視する
- 小さくイテレーション: いきなり `make release` せず `make release-check` (前提チェックのみ) で個別に潰してから通す
- コミットメッセージは日本語 + conventional prefix

### 運用前提 (brainstorming で確定した実装方式)

- 実装スタイル: **B (branch + 直列)** — このセッションで Task 1 から順に消化
- ブランチ: `feature/distribution` (作成済み。spec は `903fe14` で commit 済み)
- main 直コミット禁止。Task 5 のマージは PR を経ず fast-forward でよい (個人リポジトリ)
- 1 回だけの手動セットアップ (証明書作成 / `xcrun notarytool store-credentials`) は対話式のためユーザーが実行する

---

## ファイル構造

```
project.yml                        … MARKETING_VERSION を settings.base に追加 (Task 1)
Makefile                           … release / release-check ターゲット追加 (Task 2)
scripts/release.sh                 … リリースパイプライン本体 (Task 2, 3)
README.md                          … Homebrew インストール手順 (Task 5)
~/repos/github.com/trapple/homebrew-tap/   … 別リポジトリ (Task 4)
  Casks/glb-quicklook.rb           … cask 定義 (version/sha256 は release.sh が更新)
  README.md
```

---

### Task 1: バージョンの正を project.yml に導入

**Files:**
- Modify: `project.yml:8-12` (settings.base)

**Interfaces:**
- Produces: `settings.base.MARKETING_VERSION: "1.0.0"` — release.sh が `grep -m1 'MARKETING_VERSION:'` で読む

- [ ] **Step 1: project.yml に追記**

`settings.base` を以下に変更:

```yaml
settings:
  base:
    SWIFT_VERSION: "5.10"
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "-"
    # バージョンの正。リリース時は scripts/release.sh がここを読む
    MARKETING_VERSION: "1.0.0"
    CURRENT_PROJECT_VERSION: "1"
```

さらに、生成される Info.plist がリテラル値を焼き込まないよう、両ターゲットの `info.properties` に
ビルド設定参照を明示する (XcodeGen はデフォルトで "1.0" をリテラルで書く):

```yaml
        CFBundleShortVersionString: "$(MARKETING_VERSION)"
        CFBundleVersion: "$(CURRENT_PROJECT_VERSION)"
```

- [ ] **Step 2: ビルドして反映を確認**

実行: `make build && plutil -p build/Build/Products/Release/GLBQuickLook.app/Contents/Info.plist | grep ShortVersion` (timeout 600s)
期待: `"CFBundleShortVersionString" => "1.0.0"`

- [ ] **Step 3: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add project.yml
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "feat: MARKETING_VERSIONをproject.ymlで一元管理"
```

---

### Task 2: release.sh 前提チェック + Makefile ターゲット

**Files:**
- Create: `scripts/release.sh`
- Modify: `Makefile` (release / release-check 追加)

**Interfaces:**
- Produces: `scripts/release.sh check` = 前提チェックのみ / 引数なし = フルリリース (Task 3 で本体実装)。`version()` / `fail()` / `precheck()` 関数

- [ ] **Step 1: `scripts/release.sh` を前提チェックまで書く**

```bash
#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_SLUG="trapple/glb-quicklook"
TAP_DIR="${TAP_DIR:-$HOME/repos/github.com/trapple/homebrew-tap}"
NOTARY_PROFILE="glb-quicklook-notary"
APP="GLBQuickLook"
DERIVED="$REPO_DIR/build"

fail() { echo "❌ $1" >&2; exit 1; }

version() {
  grep -m1 'MARKETING_VERSION:' "$REPO_DIR/project.yml" | sed -E 's/.*"([^"]+)".*/\1/'
}

sign_identity() {
  security find-identity -v -p codesigning \
    | grep -m1 'Developer ID Application' \
    | sed -E 's/.*"(.+)".*/\1/'
}

precheck() {
  local v
  v="$(version)"
  [[ -n "$v" ]] || fail "project.yml から MARKETING_VERSION を読めません"
  [[ "$(git -C "$REPO_DIR" branch --show-current)" == "main" ]] \
    || fail "main ブランチで実行してください (現在: $(git -C "$REPO_DIR" branch --show-current))"
  [[ -z "$(git -C "$REPO_DIR" status --porcelain)" ]] \
    || fail "working tree がクリーンではありません"
  git -C "$REPO_DIR" fetch origin main --quiet
  [[ "$(git -C "$REPO_DIR" rev-parse main)" == "$(git -C "$REPO_DIR" rev-parse origin/main)" ]] \
    || fail "main が origin/main と一致していません (push してください)"
  if git -C "$REPO_DIR" rev-parse -q --verify "refs/tags/v$v" >/dev/null; then
    fail "tag v$v は既に存在します (project.yml の MARKETING_VERSION を上げてください)"
  fi
  [[ -n "$(sign_identity)" ]] \
    || fail "Developer ID Application 証明書がありません。Xcode → Settings → Accounts → Manage Certificates で作成してください"
  xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
    || fail "公証プロファイル '$NOTARY_PROFILE' がありません。次を実行してください: xcrun notarytool store-credentials $NOTARY_PROFILE"
  gh auth status >/dev/null 2>&1 || fail "gh が未認証です (gh auth login)"
  echo "✅ 前提チェック OK (version $v, identity: $(sign_identity))"
}

main() {
  case "${1:-release}" in
    check) precheck ;;
    release) precheck; echo "(リリース本体は未実装)"; exit 1 ;;
    *) fail "usage: release.sh [check]" ;;
  esac
}

main "$@"
```

- [ ] **Step 2: Makefile にターゲット追加**

`.PHONY` 行を `.PHONY: gen build install test ql reset fixtures vendor release release-check` に変え、末尾に追加:

```makefile
release:
	bash scripts/release.sh

release-check:
	bash scripts/release.sh check
```

- [ ] **Step 3: 失敗確認 (feature branch 上ではブランチチェックで落ちるのが正)**

実行: `chmod +x scripts/release.sh && make release-check` (timeout 60s)
期待: `❌ main ブランチで実行してください (現在: feature/distribution)` で exit 1

- [ ] **Step 4: 個別チェックの動作確認**

実行: `bash -c 'source scripts/release.sh 2>/dev/null; version'` は環境依存のため行わず、代わりに以下で関数単位を確認:
```bash
grep -m1 'MARKETING_VERSION:' project.yml | sed -E 's/.*"([^"]+)".*/\1/'   # → 1.0.0
security find-identity -v -p codesigning | grep -c 'Developer ID Application' || echo "証明書なし(要セットアップ)"
xcrun notarytool history --keychain-profile glb-quicklook-notary >/dev/null 2>&1 && echo プロファイルあり || echo "プロファイルなし(要セットアップ)"
```
期待: バージョン `1.0.0` が出る。証明書/プロファイルは未セットアップなら「なし」と出る (Task 5 でユーザーがセットアップ)

- [ ] **Step 5: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add scripts/release.sh Makefile
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "feat: リリース前提チェック (make release-check)"
```

---

### Task 3: release.sh 本体 (ビルド→公証→Release→cask更新)

**Files:**
- Modify: `scripts/release.sh` (main の release 分岐を実装)

**Interfaces:**
- Consumes: `precheck()` / `version()` / `sign_identity()` (Task 2)
- Produces: フルリリースパイプライン。cask 更新は `Casks/glb-quicklook.rb` の `version` / `sha256` 行を sed で書き換え (Task 4 の cask がこの形式を提供)

- [ ] **Step 1: release 本体の関数群を追加**

`precheck()` の下に追加し、`main()` の release 分岐を差し替え:

```bash
build_signed() {
  local identity
  identity="$(sign_identity)"
  echo "==> Release ビルド (署名: $identity)"
  make -C "$REPO_DIR" gen
  xcodebuild -project "$REPO_DIR/$APP.xcodeproj" -scheme "$APP" -configuration Release \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="$identity" \
    ENABLE_HARDENED_RUNTIME=YES \
    OTHER_CODE_SIGN_FLAGS=--timestamp \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    clean build
}

notarize_and_staple() {
  local app_path="$DERIVED/Build/Products/Release/$APP.app"
  local submit_zip="$DERIVED/$APP-notarize.zip"
  echo "==> 公証"
  ditto -c -k --keepParent "$app_path" "$submit_zip"
  if ! xcrun notarytool submit "$submit_zip" --keychain-profile "$NOTARY_PROFILE" --wait; then
    fail "公証に失敗しました。詳細: xcrun notarytool history --keychain-profile $NOTARY_PROFILE で ID を確認し、xcrun notarytool log <ID> --keychain-profile $NOTARY_PROFILE"
  fi
  echo "==> staple"
  xcrun stapler staple "$app_path"
}

create_release() {
  local v="$1" zip="$2"
  local app_path="$DERIVED/Build/Products/Release/$APP.app"
  ditto -c -k --keepParent "$app_path" "$zip"
  echo "==> tag v$v + GitHub Release"
  git -C "$REPO_DIR" tag -a "v$v" -m "v$v"
  git -C "$REPO_DIR" push origin "v$v"
  gh release create "v$v" "$zip" -R "$REPO_SLUG" --title "v$v" --generate-notes
}

update_cask() {
  local v="$1" zip="$2"
  local sha
  sha="$(shasum -a 256 "$zip" | awk '{print $1}')"
  echo "==> cask 更新 (version $v, sha256 $sha)"
  [[ -d "$TAP_DIR" ]] || git clone "git@github.com:trapple/homebrew-tap.git" "$TAP_DIR"
  local cask="$TAP_DIR/Casks/glb-quicklook.rb"
  [[ -f "$cask" ]] || fail "cask がありません: $cask"
  sed -i '' -E "s/^  version \".*\"$/  version \"$v\"/" "$cask"
  sed -i '' -E "s/^  sha256 \".*\"$/  sha256 \"$sha\"/" "$cask"
  git -C "$TAP_DIR" add Casks/glb-quicklook.rb
  git -C "$TAP_DIR" commit -m "glb-quicklook $v"
  git -C "$TAP_DIR" push
}

run_release() {
  local v
  v="$(version)"
  precheck
  build_signed
  notarize_and_staple
  local zip="$DERIVED/$APP-$v.zip"
  create_release "$v" "$zip"
  update_cask "$v" "$zip"
  echo "🎉 v$v リリース完了: https://github.com/$REPO_SLUG/releases/tag/v$v"
}

main() {
  case "${1:-release}" in
    check) precheck ;;
    release) run_release ;;
    *) fail "usage: release.sh [check]" ;;
  esac
}
```

- [ ] **Step 2: 構文チェック**

実行: `bash -n scripts/release.sh && echo OK` (timeout 30s)
期待: `OK`

- [ ] **Step 3: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add scripts/release.sh
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "feat: make release 本体 (署名→公証→Release→cask更新)"
```

---

### Task 4: Homebrew tap リポジトリ作成

**Files:**
- Create: `~/repos/github.com/trapple/homebrew-tap/Casks/glb-quicklook.rb`
- Create: `~/repos/github.com/trapple/homebrew-tap/README.md`

**Interfaces:**
- Produces: `version "..."` / `sha256 "..."` 行 (行頭スペース2) — Task 3 の `update_cask()` の sed パターンと一致すること

- [ ] **Step 1: tap リポジトリを作成**

```bash
mkdir -p ~/repos/github.com/trapple/homebrew-tap/Casks
git -C ~/repos/github.com/trapple/homebrew-tap init -b main
```

- [ ] **Step 2: `Casks/glb-quicklook.rb` を書く**

version/sha256 は初回リリース時に release.sh が書き換えるplaceholder:

```ruby
cask "glb-quicklook" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/trapple/glb-quicklook/releases/download/v#{version}/GLBQuickLook-#{version}.zip"
  name "GLB Quick Look"
  desc "Quick Look extension for glTF Binary (.glb) files"
  homepage "https://github.com/trapple/glb-quicklook"

  depends_on macos: ">= :sequoia"

  app "GLBQuickLook.app"

  caveats <<~EOS
    To register the Quick Look extension, launch the app once:
      open /Applications/GLBQuickLook.app
  EOS

  zap trash: [
    "~/Library/Containers/jp.trapple.GLBQuickLook",
    "~/Library/Containers/jp.trapple.GLBQuickLook.PreviewExtension",
  ]
end
```

- [ ] **Step 3: `README.md` を書く**

```markdown
# trapple/homebrew-tap

Personal Homebrew tap.

## Usage

    brew install trapple/tap/glb-quicklook
```

- [ ] **Step 4: sed パターン一致の確認**

実行:
```bash
sed -E 's/^  version ".*"$/  version "9.9.9"/' ~/repos/github.com/trapple/homebrew-tap/Casks/glb-quicklook.rb | grep 'version "9.9.9"'
```
期待: `  version "9.9.9"` が出力される (update_cask の sed が効く形式であること)

- [ ] **Step 5: commit して GitHub に public 作成**

```bash
git -C ~/repos/github.com/trapple/homebrew-tap add -A
git -C ~/repos/github.com/trapple/homebrew-tap commit -m "glb-quicklook cask 追加 (placeholder)"
gh repo create trapple/homebrew-tap --public --source ~/repos/github.com/trapple/homebrew-tap --push --description "Personal Homebrew tap"
```

---

### Task 5: README 更新 → マージ → 手動セットアップ → v1.0.0 通しリリース

**Files:**
- Modify: `README.md` (インストール節に Homebrew を追加)

**Interfaces:**
- Consumes: Task 1〜4 の全成果物

- [ ] **Step 1: README のビルドとインストール節の先頭に Homebrew 手順を追加**

「## ビルドとインストール」の直前に挿入:

```markdown
## インストール (Homebrew)

```bash
brew install trapple/tap/glb-quicklook
open /Applications/GLBQuickLook.app   # 初回のみ: Quick Look 拡張の登録
```
```

さらに「## 開発」節の末尾に追記:

```markdown
### リリース

1. feature branch で `project.yml` の `MARKETING_VERSION` を上げて commit → main へマージ & push
2. `make release-check` で前提を確認 (初回は Developer ID 証明書と `xcrun notarytool store-credentials glb-quicklook-notary` のセットアップが必要)
3. `make release` — 署名 → 公証 → GitHub Release → tap の cask 更新まで自動
```

- [ ] **Step 2: commit して main へマージ & push**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add README.md
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "docs: Homebrewインストールとリリース手順を追加"
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook switch main
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook merge feature/distribution
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook push
```

- [ ] **Step 3: 1回だけの手動セットアップ (ユーザー実行)**

`make release-check` を実行し、足りないものをユーザーに案内:
- 証明書: Xcode → Settings → Accounts → Manage Certificates → 「Developer ID Application」作成
- 公証: `! xcrun notarytool store-credentials glb-quicklook-notary` (チャットで `!` プレフィックス実行を案内)

`make release-check` が `✅ 前提チェック OK (version 1.0.0, ...)` になるまで繰り返す。

- [ ] **Step 4: v1.0.0 リリース実行**

実行: `make release` を run_in_background で起動し完了を監視 (公証待ちは数分かかる)
期待: `🎉 v1.0.0 リリース完了` で終了

- [ ] **Step 5: 受け入れ確認**

```bash
spctl -a -vv /Applications/GLBQuickLook.app          # → accepted, source=Notarized Developer ID
gh release view v1.0.0 -R trapple/glb-quicklook      # → zip が添付されている
brew install trapple/tap/glb-quicklook               # → 既存手動インストールを置き換え
open /Applications/GLBQuickLook.app
qlmanage -p fixtures/Box.glb                          # → 3D表示 (最終目視はユーザー)
```
期待: 4項目すべて成功。※ brew install 前に手動インストール分は brew が上書きできないため `rm -rf /Applications/GLBQuickLook.app` してから実行
