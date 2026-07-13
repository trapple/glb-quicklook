# GLB Quick Look 拡張 設計書

日付: 2026-07-12
ステータス: 承認待ち

## 目的

.glb (glTF Binary) ファイルを Finder のスペースキー (Quick Look) でプレビューできる macOS 拡張を自作する。

既存の [DeepARSDK/glb-preview](https://github.com/DeepARSDK/glb-preview) (WKWebView + model-viewer 構成) に対する不満が動機:

- WebView + JS エンジン起動による表示の遅さ・メモリ消費
- 自動回転がデフォルト ON で、設定も保存されない

## 要件

- 対応形式: **.glb のみ** (.gltf の外部参照解決はスコープ外)
- スコープ: **プレビューのみ** (Finder サムネイル拡張は作らない)
- 軽さの定義: **表示までの速度** と **メモリ/CPU 消費** を最優先
- 機能: カメラ操作 (ドラッグ回転 + ズーム + パン) と背景色切替のみ
  - パンは右ドラッグまたは Shift+ドラッグ (2026-07-13 追加。Finder プレビュー欄では
    右イベントが届かないため Shift+ドラッグが代替になる)
- **自動回転なし**。アニメーション再生なし
- 配布: 自分用 (公証不要、対応 OS 下限は開発機の macOS 26 でよい)

## 技術選定

**RealityKit + GLTFKit2** (ネイティブ実装、WebView なし)。

| 検討案 | 判定 | 理由 |
|---|---|---|
| RealityKit + GLTFKit2 | ✅ 採用 | ネイティブで軽い。Apple の現行推奨フレームワーク。カメラ操作が標準付属 |
| SceneKit + GLTFKit2 | 退避先 | 実績はあるが WWDC 2025 で正式に非推奨化。新規採用の理由が弱い |
| Metal 自作 | ✗ | 理論上最軽量だが差は誤差 (数十ms/数MB)。PBR/IBL/カメラの自前実装で工数数十倍 |
| WKWebView + three.js | ✗ | 軽さ要件と逆行 |

リスク: GLTFKit2 の RealityKit 変換 (`GLTFRealityKitLoader`) は SceneKit 変換より成熟度が低い。表示品質に問題が出た場合はパース層 (GLTFKit2) を共有したまま SceneKit 構成へ退避する。

## アーキテクチャ

Quick Look 拡張は単体配布できないため「ホストアプリ + 拡張」の 2 ターゲット構成。

```
GLBQuickLook.app (ホスト。ほぼ空。/Applications に置いて拡張を登録するだけ)
└── PreviewExtension.appex (com.apple.quicklook.preview)
    ├── PreviewViewController  … QLPreviewingController 実装。入口
    ├── ModelPreviewView       … SwiftUI。RealityView + 背景切替ボタン
    └── GLTFKit2 (バイナリ XCFramework を vendor/ に取得して埋め込み)
                               … .glb パース + RealityKit エンティティ変換
```

- **PreviewViewController**: `preparePreviewOfFile(at:)` で URL を受け取り、GLTFKit2 でロード → `NSHostingView` で SwiftUI ビューを載せる薄い層
- **ModelPreviewView**: `RealityView` にエンティティを配置。カメラは固定の `PerspectiveCamera` を自前配置し、ドラッグ回転は `NSPanGestureRecognizer` で受けてモデルの親 Entity を回す（後述「QL プレビューの入力制約」参照。当初の `.realityViewCameraControls(.orbit)` は QL 内で機能しないため廃止）。右上に背景色切替ボタンを 1 つだけ置く
- 依存は **GLTFKit2 の 1 つだけ**。JS・WebView・同梱アセットなし
  - GLTFKit2 は SPM の binaryTarget (動的 XCFramework)。SPM 経由だと XcodeGen で埋め込みが構成できないため、公式リリースの XCFramework zip (checksum 検証付き) を `vendor/` に取得してホストアプリに埋め込む
- ビルドは **XcodeGen (project.yml)** でプロジェクト定義をテキスト管理 (.xcodeproj は git 管理外)
- 対象 UTI: `org.khronos.glb` (`QLSupportedContentTypes`)

## データフロー

1. Finder でスペースキー → 拡張プロセス起動 → `preparePreviewOfFile(at url:)`
2. `GLTFAsset.load(url)` で .glb をパース (バックグラウンド実行)
3. `GLTFRealityKitLoader` で RealityKit の `Entity` に変換
4. バウンディングボックスから初期カメラ距離を計算し、モデル全体が収まるようフレーミング
5. `RealityView` に配置して表示完了

Base64 エンコードや blob URL のような中間表現なし (ファイル → パーサ直結)。

### ライティング

glTF の PBR マテリアルは環境光がないと黒く沈むため、`ImageBasedLight` にニュートラルな環境を 1 つ固定で設定する。ユーザー設定は設けない (YAGNI)。

### 背景色

ダーク (#262626) ⇄ ライト (#d9d9d9) の 2 値トグル。SwiftUI 側の背景色切替のみ。

## エラーハンドリング (Fail Fast)

- パース失敗・変換失敗は `preparePreviewOfFile` からエラーを throw し、Quick Look 標準のフォールバック (ファイル情報表示) に任せる。壊れた 3D 表示を出さない
- タイムアウトは設けない (Quick Look 自体が拡張プロセスを管理・強制終了するため二重管理になる)

## テスト方針

自動テストは最小とし、実物確認を軸にする。

**開発ループ**: ビルド → アプリを一度起動して拡張登録 (`pluginkit -m` で確認) → `qlmanage -p sample.glb` で直接プレビュー起動。

**テスト用アセット** ([Khronos glTF-Sample-Assets](https://github.com/KhronosGroup/glTF-Sample-Assets) から `fixtures/` に取得):

| ファイル | 確認内容 |
|---|---|
| Box.glb | 最小ケースが表示される |
| Duck.glb | テクスチャ付きが正しく出る |
| DamagedHelmet.glb | PBR マテリアル + IBL の見栄え |
| Fox.glb (アニメ入り) | アニメ再生機能はないがクラッシュしないこと |
| 壊れたファイル (自作) | 標準フォールバックへ落ちること |

## 受け入れ条件

1. Finder でスペースキー → 小さいモデルなら体感即座 (1 秒以内目安) に表示される
2. ドラッグで回転、スクロール/ピンチでズームできる
3. 背景色トグルが効く
4. 勝手に回転しない
5. 不正な .glb でクラッシュせず標準フォールバックする

## QL プレビューの入力制約 (2026-07-13 追記: 「回転が効かない」障害の対策)

実地報告「QL プレビューでスクロールズームは効くが、ドラッグ回転が効かない」への対策。
姉妹プロジェクト ifc-quicklook での原因究明 (同名日付の設計書・commit 28617d8) で
確定した事実の移植:

- **ドラッグは NSPanGestureRecognizer で受けること (最終解)**。QL のリモートビュー
  転送 (ViewBridge) は生の mouseDown/mouseDragged を表示面ごとに違う形で殺す:
  - スペースキーパネル: 生イベントはビューに届くが **deltaX/deltaY が 0 に潰される**
  - Finder プレビュー欄: 生イベントは**プロセスには届く**のに、ホスト側機構
    (ファイルドラッグ判定等) に消費されてビューの override までほぼ届かない
  - `.realityViewCameraControls(.orbit)` はこの生イベントに依存するため QL 内では
    回転が効かなかった → 廃止。レコグナイザはホストとのイベント調停に乗るため
    両方の面で機能し、`translation(in:)` はデルタ潰しの影響も受けない
    (Apple 純正 usdz プレビュー = RAQLPreviewExtension.appex と同方式)
- **ただし右 (中) ボタンは逆** (ifc-quicklook commit cbd1302 での実測知見):
  buttonMask を指定したパンレコグナイザは QL パネルでは一切発火しない。一方、
  右ボタンの生イベント (rightMouseDown/rightMouseDragged) はパネルでもビューまで
  届く (左と違いホストに食われない。delta は例によって 0 潰しなので
  locationInWindow の位置差分で計算する)。つまり
  **「左＝レコグナイザ / 右＝生イベント＋位置差分」のハイブリッド**が全表示面で
  動く構成。Finder 欄では右イベント自体が届かないため、欄でのパンは
  Shift+ドラッグで代替する。パン実装 (InteractionView) はこの構成に従う
- ズームは当初 NSEvent ローカルモニタで受けていたが、ビューの scrollWheel /
  magnify override もどの面でも届く (ifc-quicklook 実測)。appex とアプリで
  コードを共有するため InteractionView の override に統合した
- 入力→変換の対応 (すべて原点中心の親 Entity の変換書き換えで同型):
  ズーム=scale / 回転=orientation (ターンテーブル) / パン=position。
  ModelTransformController に集約
- スクロール (scrollingDeltaY) とピンチ (magnification) はどの面でも潰されず届く
  (ズームだけ効いていた理由)。ズームのイベントモニタ方式は現状維持
- ジェスチャを受ける NSView には `acceptsFirstMouse(for:) = true` と
  `acceptsFirstResponder = true` を付ける (Finder 欄はホストウィンドウが key に
  ならず、最初のクリックが click-through 防止で捨てられるため)
- カメラは `.realityViewCameraControls` 廃止に伴い固定の `PerspectiveCamera` を
  自前配置。回転はズーム (原点中心の親 Entity の等倍スケール) と同型の
  「親 Entity の orientation 書き換え」(ターンテーブル方式、pitch は ±90° クランプ)
- **デバッグの罠**: appex の NSLog / os_log は `log show` で一切観測できない。
  appex 内の観測はコンテナ tmp (NSTemporaryDirectory) へのファイル追記で行う
- 合成 CGEvent はスペースキーパネルには効くが、Finder プレビュー欄では実マウスと
  挙動が異なり**偽陰性を出す**。欄の最終確認は実マウスでしか出来ない

## スコープ外 (将来の拡張候補)

- Finder サムネイル拡張
- .gltf (外部参照) 対応
- アニメーション再生
- Developer ID 署名 + 公証、Homebrew cask 等の配布整備
