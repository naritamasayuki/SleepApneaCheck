import AppTrackingTransparency
import Foundation
import os
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Google AdMob 広告の初期化と ATT（トラッキング許可）を管理するサービス
@MainActor
final class AdService: ObservableObject {
    /// バナー広告ユニット ID（DEBUG 時はテスト広告、Release 本番ビルドでは本番 ID を使用）
    #if DEBUG
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    #else
    static let bannerAdUnitID = "ca-app-pub-4261439423960578/2440707258"
    #endif

    @Published private(set) var isInitialized = false
    private let logger = Logger(subsystem: "com.naritamasayuki.sleepapneacheck", category: "AdService")

    /// ATT 許可を確認した上で AdMob SDK を初期化する
    func configureIfNeeded() async {
        guard !isInitialized else { return }

        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            // 画面描画が安定してから ATT ダイアログを表示
            try? await Task.sleep(nanoseconds: 600_000_000)
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        #if canImport(GoogleMobileAds)
        await withCheckedContinuation { continuation in
            MobileAds.shared.start { status in
                let adapters = status.adapterStatusesByClassName.keys.joined(separator: ", ")
                self.logger.info("AdMob SDK 初期化完了: \(adapters)")
                continuation.resume()
            }
        }
        #endif

        isInitialized = true
    }
}
