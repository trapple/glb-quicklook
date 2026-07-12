# GLB Quick Look 拡張 実装プラン

> **実装者向け:** このプランは subagent-driven-development (推奨) または手動実行で消化する。step は `- [ ]` チェックボックスで track する。

**Goal:** .glb を Finder のスペースキーでネイティブ表示する macOS Quick Look 拡張 (自動回転なし・カメラ操作+背景切替のみ) を作る。

**Architecture:** ホストアプリ `GLBQuickLook.app` + Quick Look Preview 拡張の 2 ターゲット構成。拡張は `GLTFRealityKitLoader.load(from:)` で .glb を RealityKit `Entity` に変換し、SwiftUI `RealityView` + `.realityViewCameraControls(.orbit)` で表示する。WebView/JS は使わない。

**Tech Stack:** Swift / SwiftUI / RealityKit / GLTFKit2 (SPM, 唯一の依存) / XcodeGen / Make

## Global Constraints

### Spec 由来 (spec から逐語コピー)

- 対応形式: **.glb のみ** (.gltf の外部参照解決はスコープ外)
- スコープ: **プレビューのみ** (Finder サムネイル拡張は作らない)
- 機能: カメラ操作 (ドラッグ回転 + ズーム) と背景色切替のみ。**自動回転なし**。アニメーション再生なし
- 依存は **GLTFKit2 の 1 つだけ**。JS・WebView・同梱アセットなし
- ビルドは **XcodeGen (project.yml)** でプロジェクト定義をテキスト管理 (.xcodeproj は git 管理外)
- 対象 UTI: `org.khronos.glb`
- エラー時: `preparePreviewOfFile` から throw し Quick Look 標準フォールバックに任せる。タイムアウトは設けない
- 背景色: ダーク (#262626) ⇄ ライト (#d9d9d9) の 2 値トグル
- 配布: 自分用 (公証不要)。「対応 OS 下限は開発機の macOS 26 でよい」→ deploymentTarget は使用 API (`RealityView` + orbit controls) の下限である **15.0** とする (spec の許容範囲内でより低い値)

### PJ 恒久ルール (CLAUDE.md / `.claude/rules/` 由来)

- git 操作は `git -C <dir> ...` を使う (cd しない)
- 外部プロセス起動 (xcodebuild / curl 等) には必ず timeout を指定する
- 小さくイテレーションを回す: 1 ケース確認 → 全ケース、の順
- コミットメッセージは日本語 + conventional prefix (既存コミット `docs(specs): ...` に倣う)

### 運用前提 (brainstorming で確定した実装方式)

- 実装スタイル: **B (branch + 直列)** — このセッションで Task 1 から順に消化
- ブランチ: `feature/glb-quicklook-mvp` (作成済み。spec は `619cde4` で commit 済み)
- main 直コミット禁止

---

## ファイル構造

```
project.yml                                … XcodeGen 定義 (全ターゲット・Info.plist・entitlements)
Makefile                                   … gen/build/install/test/fixtures/ql ヘルパー
.gitignore
README.md                                  … ビルド/インストール手順 (Task 4)
GLBQuickLook/
  GLBQuickLookApp.swift                    … ホストアプリ (ほぼ空の案内ウィンドウ)
PreviewExtension/
  PreviewViewController.swift              … QLPreviewingController 実装 (入口)
  ModelPreviewView.swift                   … RealityView + 背景切替ボタン
  EntityFraming.swift                      … フレーミング計算 (純関数・テスト対象)
Tests/
  EntityFramingTests.swift
fixtures/                                  … テスト用 .glb (git 管理外、Makefile で取得)
```

---

### Task 1: プロジェクト scaffolding + QL 拡張スケルトン

Quick Look 配線 (登録 → スペースキーでビューが出る) をテキスト表示だけの拡張で end-to-end に通す。

**Files:**
- Create: `.gitignore`
- Create: `project.yml`
- Create: `Makefile`
- Create: `GLBQuickLook/GLBQuickLookApp.swift`
- Create: `PreviewExtension/PreviewViewController.swift`

**Interfaces:**
- Produces: `PreviewViewController` (Task 3 で中身を差し替える) / `make build` `make install` `make fixtures` (以降の全 Task が使う)

- [ ] **Step 1: ツール確認**

実行: `which xcodegen || brew install xcodegen` (timeout 300s)
期待: xcodegen のパスが表示される

- [ ] **Step 2: `.gitignore` を書く**

```gitignore
*.xcodeproj
build/
fixtures/
.DS_Store
```

- [ ] **Step 3: `project.yml` を書く**

```yaml
name: GLBQuickLook
options:
  bundleIdPrefix: jp.trapple
  deploymentTarget:
    macOS: "15.0"
  createIntermediateGroups: true

settings:
  base:
    SWIFT_VERSION: "5.10"
    CODE_SIGN_STYLE: Manual
    CODE_SIGN_IDENTITY: "-"

packages:
  GLTFKit2:
    url: https://github.com/warrenm/GLTFKit2
    from: "0.5.0"

targets:
  GLBQuickLook:
    type: application
    platform: macOS
    sources: [GLBQuickLook]
    info:
      path: GLBQuickLook/Info.plist
      properties:
        NSPrincipalClass: NSApplication
        NSMainStoryboardFile: ""
        CFBundleDocumentTypes:
          - CFBundleTypeName: glTF Binary
            CFBundleTypeRole: Viewer
            LSHandlerRank: Default
            LSItemContentTypes: [org.khronos.glb]
        UTImportedTypeDeclarations:
          - UTTypeIdentifier: org.khronos.glb
            UTTypeDescription: glTF Binary
            UTTypeConformsTo: [public.data, public.3d-content]
            UTTypeTagSpecification:
              public.filename-extension: [glb]
              public.mime-type: [model/gltf-binary]
    dependencies:
      - target: PreviewExtension
        embed: true

  PreviewExtension:
    type: app-extension
    platform: macOS
    sources: [PreviewExtension]
    dependencies:
      - package: GLTFKit2
    entitlements:
      path: PreviewExtension/PreviewExtension.entitlements
      properties:
        com.apple.security.app-sandbox: true
    info:
      path: PreviewExtension/Info.plist
      properties:
        CFBundleDisplayName: GLB Preview
        NSExtension:
          NSExtensionPointIdentifier: com.apple.quicklook.preview
          NSExtensionPrincipalClass: "$(PRODUCT_MODULE_NAME).PreviewViewController"
          NSExtensionAttributes:
            QLSupportedContentTypes: [org.khronos.glb]
            QLSupportsSearchableItems: false
```

- [ ] **Step 4: `Makefile` を書く**

```makefile
APP := GLBQuickLook
DERIVED := build
FIXTURE_BASE := https://github.com/KhronosGroup/glTF-Sample-Assets/raw/main/Models

.PHONY: gen build install test ql reset fixtures

gen:
	xcodegen generate

build: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Release \
		-derivedDataPath $(DERIVED) build

install: build
	rm -rf /Applications/$(APP).app
	cp -R $(DERIVED)/Build/Products/Release/$(APP).app /Applications/
	open /Applications/$(APP).app

test: gen
	xcodebuild -project $(APP).xcodeproj -scheme $(APP) -configuration Debug \
		-derivedDataPath $(DERIVED) test

ql:
	qlmanage -p fixtures/Box.glb

reset:
	qlmanage -r && qlmanage -r cache

fixtures:
	mkdir -p fixtures
	curl -L --max-time 120 -o fixtures/Box.glb           $(FIXTURE_BASE)/Box/glTF-Binary/Box.glb
	curl -L --max-time 120 -o fixtures/Duck.glb          $(FIXTURE_BASE)/Duck/glTF-Binary/Duck.glb
	curl -L --max-time 120 -o fixtures/DamagedHelmet.glb $(FIXTURE_BASE)/DamagedHelmet/glTF-Binary/DamagedHelmet.glb
	curl -L --max-time 120 -o fixtures/Fox.glb           $(FIXTURE_BASE)/Fox/glTF-Binary/Fox.glb
	printf 'this is not a glb' > fixtures/broken.glb
```

- [ ] **Step 5: ホストアプリ `GLBQuickLook/GLBQuickLookApp.swift` を書く**

```swift
import SwiftUI

@main
struct GLBQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 12) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("GLB Quick Look")
                    .font(.title2)
                Text("Finder で .glb を選んでスペースキーを押すとプレビューされます。\nこのアプリは拡張を登録するためだけに存在します。")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .frame(minWidth: 420, minHeight: 240)
        }
    }
}
```

- [ ] **Step 6: スケルトン `PreviewExtension/PreviewViewController.swift` を書く**

ファイル名表示だけの仮実装。QL 配線の疎通確認用で、Task 3 で置き換える。

```swift
import Cocoa
import QuickLookUI

class PreviewViewController: NSViewController, QLPreviewingController {

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        let label = NSTextField(labelWithString: url.lastPathComponent)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
```

- [ ] **Step 7: ビルドが通ることを確認**

実行: `make build` (timeout 600s — 初回は SPM 解決が走る)
期待: `** BUILD SUCCEEDED **`

- [ ] **Step 8: fixtures 取得 + インストールして QL 配線を確認**

実行:
```bash
make fixtures        # timeout 300s
make install         # timeout 600s
pluginkit -m | grep -i glb
make ql
```
期待: pluginkit に `jp.trapple.GLBQuickLook.PreviewExtension` が現れ、qlmanage ウィンドウに `Box.glb` というファイル名テキストが表示される。
(拡張が出ない場合は一度 `make reset` → Finder 再起動 `killall Finder` を試す)

- [ ] **Step 9: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add .gitignore project.yml Makefile GLBQuickLook PreviewExtension
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "feat: QL拡張スケルトン (ホストアプリ + テキスト表示のプレビュー配線)"
```

---

### Task 2: フレーミング計算 (TDD)

モデルを原点中心・単位サイズに正規化する純関数。RealityView のカメラがどんなサイズのモデルでも同じ距離感で映るための土台。

**Files:**
- Create: `PreviewExtension/EntityFraming.swift`
- Create: `Tests/EntityFramingTests.swift`
- Modify: `project.yml` (UnitTests ターゲットと scheme を追加)

**Interfaces:**
- Produces: `framingTransform(center: SIMD3<Float>, extents: SIMD3<Float>, targetExtent: Float = 1.0) -> (scale: Float, translation: SIMD3<Float>)` — Task 3 の `ModelPreviewView` が使用

- [ ] **Step 1: 失敗するテストを書く (`Tests/EntityFramingTests.swift`)**

```swift
import XCTest

final class EntityFramingTests: XCTestCase {

    func testUnitCubeAtOriginIsIdentity() {
        let t = framingTransform(center: .zero, extents: SIMD3<Float>(1, 1, 1))
        XCTAssertEqual(t.scale, 1.0, accuracy: 1e-6)
        XCTAssertEqual(t.translation, SIMD3<Float>(0, 0, 0))
    }

    func testOffsetLargeModelIsCenteredAndScaled() {
        // 中心 (10,20,30)・最大辺 4 → scale 0.25、中心が原点に移動
        let t = framingTransform(center: SIMD3<Float>(10, 20, 30), extents: SIMD3<Float>(4, 2, 1))
        XCTAssertEqual(t.scale, 0.25, accuracy: 1e-6)
        XCTAssertEqual(t.translation.x, -2.5, accuracy: 1e-6)
        XCTAssertEqual(t.translation.y, -5.0, accuracy: 1e-6)
        XCTAssertEqual(t.translation.z, -7.5, accuracy: 1e-6)
    }

    func testZeroExtentDoesNotDivideByZero() {
        // 空シーン/点のみ: scale 1 で中心移動のみ
        let t = framingTransform(center: SIMD3<Float>(1, 1, 1), extents: .zero)
        XCTAssertEqual(t.scale, 1.0)
        XCTAssertEqual(t.translation, SIMD3<Float>(-1, -1, -1))
    }
}
```

- [ ] **Step 2: `project.yml` に UnitTests ターゲットと scheme を追加**

`targets:` の末尾に追加:

```yaml
  UnitTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - Tests
      - path: PreviewExtension/EntityFraming.swift
```

トップレベル (`packages:` の上あたり) に追加:

```yaml
schemes:
  GLBQuickLook:
    build:
      targets:
        GLBQuickLook: all
    run:
      config: Release
    test:
      targets: [UnitTests]
```

- [ ] **Step 3: 実行して失敗を確認**

実行: `touch PreviewExtension/EntityFraming.swift && make test` (timeout 600s)
期待: FAIL (`cannot find 'framingTransform' in scope` のコンパイルエラー)

- [ ] **Step 4: 最小実装 (`PreviewExtension/EntityFraming.swift`)**

```swift
import simd

/// モデルを原点中心・最大辺 targetExtent に正規化する scale と translation を返す。
/// extents が 0 や非有限のとき (空シーン等) は scale 1 で中心移動のみ。
func framingTransform(
    center: SIMD3<Float>,
    extents: SIMD3<Float>,
    targetExtent: Float = 1.0
) -> (scale: Float, translation: SIMD3<Float>) {
    let maxExtent = max(extents.x, max(extents.y, extents.z))
    guard maxExtent > 0, maxExtent.isFinite else {
        return (1.0, -center)
    }
    let scale = targetExtent / maxExtent
    return (scale, -center * scale)
}
```

- [ ] **Step 5: 実行して通過を確認**

実行: `make test` (timeout 600s)
期待: `** TEST SUCCEEDED **` (3 テスト PASS)

- [ ] **Step 6: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add project.yml PreviewExtension/EntityFraming.swift Tests/EntityFramingTests.swift
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "feat: モデルフレーミング計算をTDDで追加"
```

---

### Task 3: RealityKit プレビュー本体

スケルトンを GLTFKit2 + RealityView の実実装に差し替える。

**Files:**
- Create: `PreviewExtension/ModelPreviewView.swift`
- Modify: `PreviewExtension/PreviewViewController.swift` (Task 1 のスケルトンを全置換)

**Interfaces:**
- Consumes: `framingTransform(center:extents:targetExtent:)` (Task 2) / `GLTFRealityKitLoader.load(from: URL) async throws -> RealityKit.Entity` (GLTFKit2)
- Produces: 完成したプレビュー UI

- [ ] **Step 1: `PreviewExtension/ModelPreviewView.swift` を書く**

```swift
import SwiftUI
import RealityKit

struct ModelPreviewView: View {
    let modelEntity: Entity
    @State private var isDarkBackground = true

    // spec: ダーク #262626 ⇄ ライト #d9d9d9
    private var backgroundColor: Color {
        isDarkBackground
            ? Color(red: 0x26 / 255.0, green: 0x26 / 255.0, blue: 0x26 / 255.0)
            : Color(red: 0xd9 / 255.0, green: 0xd9 / 255.0, blue: 0xd9 / 255.0)
    }

    var body: some View {
        RealityView { content in
            let bounds = modelEntity.visualBounds(relativeTo: nil)
            let framing = framingTransform(center: bounds.center, extents: bounds.extents)
            modelEntity.scale = SIMD3<Float>(repeating: framing.scale)
            modelEntity.position = framing.translation
            content.add(modelEntity)
        }
        .realityViewCameraControls(.orbit)
        .background(backgroundColor)
        .overlay(alignment: .topTrailing) {
            Button {
                isDarkBackground.toggle()
            } label: {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14))
                    .foregroundStyle(isDarkBackground ? .white : .black)
            }
            .buttonStyle(.plain)
            .padding(10)
            .help("背景色を切り替え")
        }
    }
}
```

- [ ] **Step 2: `PreviewExtension/PreviewViewController.swift` を全置換**

```swift
import Cocoa
import QuickLookUI
import SwiftUI
import GLTFKit2

class PreviewViewController: NSViewController, QLPreviewingController {

    override func loadView() {
        view = NSView()
    }

    func preparePreviewOfFile(at url: URL) async throws {
        // 失敗時はそのまま throw し、Quick Look 標準フォールバックに任せる (Fail Fast)
        let entity = try await GLTFRealityKitLoader.load(from: url)
        let hostingView = NSHostingView(rootView: ModelPreviewView(modelEntity: entity))
        hostingView.frame = view.bounds
        hostingView.autoresizingMask = [.width, .height]
        view.addSubview(hostingView)
    }
}
```

- [ ] **Step 3: ビルド + 実機確認 (Box.glb)**

実行: `make install && make ql` (timeout 600s)
期待: 立方体が表示され、ドラッグで回転・スクロールでズームできる。**勝手に回転しない**。

※ spec の「`ImageBasedLight` にニュートラル環境を固定設定」は、まず RealityView のデフォルト照明で見え方を確認し、不足する場合のみ下記の光源追加で満たす方針に読み替える (受け入れ条件は「マテリアルが判別できること」)。実装が確定したら spec のライティング節を実態に合わせて更新すること。

うまくいかない場合の分岐 (症状 → 対処コードを `RealityView { content in ... }` の `content.add(modelEntity)` の直後に追加):

モデルが見えない/極小 → カメラを明示配置:
```swift
let camera = PerspectiveCamera()
camera.look(at: .zero, from: SIMD3<Float>(0, 0.3, 1.6), relativeTo: nil)
content.add(camera)
```

モデルが真っ黒 → 光源を明示追加:
```swift
let light = DirectionalLight()
light.light.intensity = 2000
light.orientation = simd_quatf(angle: -.pi / 4, axis: SIMD3<Float>(1, 0, 0))
content.add(light)
```

- [ ] **Step 4: テクスチャ/PBR 確認**

実行: `qlmanage -p fixtures/Duck.glb` → 目視、`qlmanage -p fixtures/DamagedHelmet.glb` → 目視 (各 timeout 60s)
期待: Duck は黄色いテクスチャ、DamagedHelmet は金属質のマテリアルが判別できる。背景トグルボタンで #262626 ⇄ #d9d9d9 が切り替わる。

- [ ] **Step 5: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add PreviewExtension
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "feat: RealityKitによるGLBプレビュー本体 (カメラ操作+背景切替)"
```

---

### Task 4: 受け入れ確認 + README

spec の受け入れ条件 5 項目を通し、最小限の README を残す。

**Files:**
- Create: `README.md`

**Interfaces:**
- Consumes: Task 1〜3 の全成果物

- [ ] **Step 1: エッジケース確認**

実行:
```bash
qlmanage -p fixtures/Fox.glb      # アニメ入り: 再生されなくてよい。クラッシュしないこと
qlmanage -p fixtures/broken.glb   # 壊れたファイル: QL標準フォールバック(ファイル情報)に落ちること
```
(各 timeout 60s)
期待: どちらもクラッシュ・ハングしない。

- [ ] **Step 2: Finder で受け入れ条件 5 項目を通す (手動)**

Finder で `fixtures/` を開き、ユーザーに以下を確認してもらう:

1. スペースキー → 体感即座 (1 秒以内目安) に表示
2. ドラッグで回転、スクロール/ピンチでズーム
3. 背景色トグルが効く
4. 勝手に回転しない
5. broken.glb で標準フォールバック

- [ ] **Step 3: `README.md` を書く**

```markdown
# GLB Quick Look

.glb (glTF Binary) を Finder のスペースキーでプレビューする macOS Quick Look 拡張。
RealityKit + GLTFKit2 によるネイティブ実装 (WebView なし・自動回転なし)。

## ビルドとインストール

要件: macOS 15+ / Xcode / xcodegen (`brew install xcodegen`)

```bash
make install   # xcodegen → xcodebuild → /Applications に配置 → 起動 (拡張登録)
```

プレビューが出ないときは `make reset` (qlmanage キャッシュリセット) と `killall Finder`。

## 開発

```bash
make fixtures  # テスト用 .glb を fixtures/ に取得
make test      # ユニットテスト
make ql        # qlmanage -p fixtures/Box.glb で直接プレビュー起動
```

設計: `.claude/specs/2026-07-12-glb-quicklook-design.md`
```

- [ ] **Step 4: commit**

```bash
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook add README.md
git -C /Users/trapple/repos/github.com/trapple/glb-quicklook commit -m "docs: README追加 (受け入れ確認完了)"
```
