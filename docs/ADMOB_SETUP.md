# Google AdMob 本番切り替えガイド（v1.1 向け）

現在、アプリには Google 公式の **テスト用 AdMob ID** が設定されています。
v1.0 の審査通過後、本番広告を有効にして v1.1 をリリースする際は、以下の2箇所をご自身の AdMob ID に差し替えてください。

## 1. 本番 ID への差し替え箇所

1. **`SleepApneaCheck/Resources/Info.plist`**
   - `GADApplicationIdentifier` の値を、AdMob 管理画面で作成した **アプリ ID**（`ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy`）に変更します。
2. **`SleepApneaCheck/Services/AdService.swift`**
   - `bannerAdUnitID` の値を、AdMob 管理画面で作成した **バナー広告ユニット ID**（`ca-app-pub-xxxxxxxxxxxxxxxx/zzzzzzzzzz`）に変更します。

## 2. App Store Connect「アプリのプライバシー」更新（重要）

AdMob を本番有効化して v1.1 を提出する際は、App Store Connect の **「アプリのプライバシー」** を以下のように更新してください：
- **データ収集**: 「はい、この App からデータを収集します」
- 収集データ項目（AdMob 標準）:
  - **識別子 > デバイス ID**（サードパーティ広告 / トラッキングに使用）
  - **使用状況データ > 広告データ**（サードパーティ広告 / 分析に使用）
  - **診断 > クラッシュデータ / パフォーマンスデータ**（アプリの安定性・分析）

## 3. 広告表示の仕様

- 全機能を完全無料で提供（アプリ内課金なし）しており、各画面下部にバナー広告を表示します。
- 睡眠録音中（`isRecording == true`）は画面をシンプルに保つため、バナー広告は自動的に非表示になります。
