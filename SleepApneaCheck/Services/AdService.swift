import AppTrackingTransparency
import Foundation
import os
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// Google AdMob 広告の初期化と UMP（EEA/UK同意）・ATT（トラッキング許可）を管理するサービス
@MainActor
final class AdService: ObservableObject {
    /// バナー広告ユニット ID（DEBUG 時はテスト広告、Release 本番ビルドでは本番 ID を使用）
    #if DEBUG
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"
    #else
    static let bannerAdUnitID = "ca-app-pub-4261439423960578/2440707258"
    #endif

    @Published private(set) var isInitialized = false
    /// UMP 同意状態に基づき広告リクエスト可能か（UMP 非導入環境では true）
    @Published private(set) var canRequestAds = false
    /// EEA/UK 等でプライバシーオプション（同意変更）の入口表示が必要か
    @Published private(set) var isPrivacyOptionsRequired = false
    private let logger = Logger(subsystem: "com.naritamasayuki.sleepapneacheck", category: "AdService")

    /// UMP 同意確認 → ATT 許可確認 → AdMob SDK 初期化の順で安全に実行する
    func configureIfNeeded() async {
        guard !isInitialized else { return }

        // 1. EEA/UK 向け UMP 同意情報の確認（Google CMP 要件対応）
        #if canImport(UserMessagingPlatform)
        await requestUMPConsentIfNeeded()
        canRequestAds = ConsentInformation.shared.canRequestAds
        isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #else
        canRequestAds = true
        #endif

        // 2. ATT（トラッキング許可）の確認
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            // 画面描画が安定してから ATT ダイアログを表示
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }

        // 3. AdMob SDK の初期化（同意が得られない場合は SDK を開始せず広告も出さない）
        guard canRequestAds else { return }
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

    #if canImport(UserMessagingPlatform)
    /// UMP プライバシーオプション（広告同意の変更フォーム）を表示する
    func presentPrivacyOptions() async {
        guard let rootVC = Self.activeRootViewController else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: rootVC)
            canRequestAds = ConsentInformation.shared.canRequestAds
            isPrivacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        } catch {
            logger.warning("UMP プライバシーオプション表示失敗: \(error.localizedDescription)")
        }
    }

    private func requestUMPConsentIfNeeded() async {
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false

        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if let rootVC = Self.activeRootViewController {
                try await ConsentForm.loadAndPresentIfRequired(from: rootVC)
            }
        } catch {
            logger.warning("UMP 同意処理スキップ: \(error.localizedDescription)")
        }
    }

    private static var activeRootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
    #endif
}
