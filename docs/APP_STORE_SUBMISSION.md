# App Store 提出ガイド & メタデータ

## 1. 提出前チェックリスト（実装・設定済み項目）
- [x] **アプリアイコン**: `1024x1024` 不透明PNG（`AppIcon.png`）を `Assets.xcassets/AppIcon.appiconset` に配置済み
- [x] **Privacy Manifest**: `SleepApneaCheck/Resources/PrivacyInfo.xcprivacy` を作成・組み込み済み（`NSPrivacyTracking = true`、AdMob 収集データ型および `UserDefaults`: `CA92.1`）
- [x] **輸出コンプライアンス**: `Info.plist` に `ITSAppUsesNonExemptEncryption = false` を設定済み
- [x] **バックグラウンド録音**: `Info.plist` に `UIBackgroundModes: audio` および 4言語の `NSMicrophoneUsageDescription` を設定済み
- [x] **医療免責事項**: 簡易判定結果内・詳細問診・録音画面・設定画面に医療機器ではない旨の免責表示を実装済み
- [x] **マネタイズ設計（完全無料・アプリ内課金なし）**: 全機能を完全無料で提供し、Google AdMob バナー広告（UMP/ATT対応）および Amazon アソシエイト（PR表記あり）で運営

---

## 2. 提出前に開発者側で行う作業（App Store Connect / Xcode）
1. **Bundle Identifier & Team 設定**:
   - Xcode > Signing & Capabilities で Apple Developer Team（`4KR684T6KV`）を選択し、`com.naritamasayuki.sleepapneacheck` をプロビジョニングする。
2. **プライバシーポリシー公開 URL の設定**:
   - App Store Connect の「アプリのプライバシー」に公開URL（`https://naritamasayuki.github.io/SleepApneaCheck/privacy-policy.html`）を設定する。
3. **Archive & Upload**:
   - `xcodebuild archive` および `xcodebuild -exportArchive`（または Xcode `Product > Archive`）で App Store Connect へアップロードする。

---

## 3. App Store Connect 入力用メタデータ案

### アプリ名
- **日本語**: 睡眠時無呼吸チェック - いびき・無呼吸セルフ診断
- **英語**: SleepApnea Check: Snore & Risk

### サブタイトル（30文字以内）
- **日本語**: 30秒簡易判定＆睡眠録音でリスクを見える化
- **英語**: Quick Risk Check & Sleep Audio

### キーワード
- **日本語**: `睡眠時無呼吸症候群,いびき,無呼吸,睡眠,セルフチェック,STOP-Bang,眠気,録音,健康`
- **英語**: `sleep apnea,snoring,STOP-Bang,sleepiness,breathing,self check,sleep tracker,ESS`

### 概要（Description / 日本語）
```text
「いびきがうるさいと言われた」「日中に強い眠気がある」「寝ている間に息が止まっているかも」——
そんな不安を、医学的スクリーニング指標と睡眠録音で手軽にセルフチェックできるアプリです。

■ 主な機能
1. 30秒 簡易判定（5問チェック）
5つの質問に答えるだけで、睡眠時無呼吸症候群のリスク傾向をすぐ確認できます。

2. 詳細問診（STOP-Bang / エプワース眠気尺度 ESS）
医療機関でも用いられる国際的なスクリーニング指標に基づき、リスクと日中の眠気を詳しくチェック。身長・体重からのBMI自動計算や、医師へ共有できるサマリー出力に対応しています。

3. 睡眠録音＆簡易解析
枕元に置いて録音するだけで、いびき区間や10秒以上の無音（無呼吸候補）区間を自動検出し、タイムラインで可視化します。

4. 履歴・推移グラフ
過去の問診スコアや睡眠録音の結果をグラフで振り返ることができます。

■ 医療免責事項
本アプリはセルフチェック用の補助ツールであり、医療機器ではありません。医学的診断を行うものではないため、高リスク判定が出た場合や自覚症状がある場合は、必ず睡眠外来・呼吸器内科などの専門医を受診してください。
```

### App Review 審査メモ（App Review Notes / 英語推奨）
```text
Thank you for reviewing SleepApnea Check.

1. Medical Disclaimer:
This app is strictly a self-check screening & sleep sound logging tool, NOT a medical device. Clear medical disclaimers are displayed on the screening screen, inside the quick-check result card, on the sleep monitor screen, and in Settings.

2. Testing Audio Analysis without Overnight Recording:
In the "Monitor" tab, reviewers can tap "Run Sample Audio Simulation" to immediately verify the snoring and breathing-pause detection algorithm and timeline chart using a synthesized 60-second sleep waveform.

3. Microphone Permission:
Requested only when the user taps "Start Sleep Recording" in the Monitor tab, solely for local on-device sleep sound analysis. No audio is uploaded to external servers.

4. Monetization (100% Free, No In-App Purchases):
All features are completely free with no In-App Purchases. The app is supported by Google AdMob banner ads (with UMP & ATT) and Amazon Associate links clearly labeled as "PR".
```
