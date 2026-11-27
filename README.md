# SleepApnea Check (睡眠時無呼吸チェック)

睡眠時無呼吸症候群（SAS / OSA）のセルフチェックを行うための iOS アプリ（Swift / SwiftUI）です。

> **免責事項**: 本アプリはセルフチェック用の補助ツールであり、医療機器ではありません。医学的診断を行うものではないため、高リスク判定が出た場合や自覚症状がある場合は、必ず睡眠外来・呼吸器内科などの専門医を受診してください。

## 主な機能

1. **医学的問診チェック（STOP-Bang / エプワース眠気尺度 ESS）**
   - STOP-Bang 8項目（身長・体重からの BMI 自動計算機能付き）
   - エプワース眠気尺度（ESS）8項目（0〜3点評価）
   - 総合リスク判定（低・中・高）および医師・家族共有用サマリー出力
2. **睡眠音声モニタリング＆簡易解析**
   - `AVAudioRecorder` による睡眠中の録音（バックグラウンド録音対応）
   - `AudioAnalyzer` によるノイズフロア推定・いびき区間・10秒以上の無呼吸候補区間の検出
   - タイムラインチャート（Swift Charts）および録音再生機能
   - 実機マイクが使えない環境向けのシミュレーション解析モード搭載
3. **履歴・傾向管理**
   - 問診結果および睡眠録音解析結果のローカル保存（JSON永続化）
   - Swift Charts によるスコア・イベント推移の可視化
4. **多言語対応（i18n / L10n）**
   - 日本語 (`ja`)、英語 (`en`)、中国語簡体字 (`zh-Hans`)、中国語繁体字 (`zh-Hant`) に対応（未対応言語は英語フォールバック）
5. **収益化設計（完全無料・アプリ内課金なし）**
   - すべての機能を完全無料で提供し、Google AdMob バナー広告（UMP/ATT対応）および睡眠ケアグッズの Amazon アソシエイト（PR表記）で運営

## 動作環境・ビルド方法

- Xcode 16+ / iOS 17.0+
- `SleepApneaCheck.xcodeproj` を Xcode で開いてビルド・実行してください。

### CLI でのテスト実行
```bash
xcodebuild test \
  -project SleepApneaCheck.xcodeproj \
  -scheme SleepApneaCheck \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro'
```
