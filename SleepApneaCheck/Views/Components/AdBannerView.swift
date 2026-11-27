import os
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// 画面下部へ表示するバナー広告ビュー（UMP同意およびSDK初期化完了後にのみリクエスト）
struct AdBannerView: View {
    @EnvironmentObject private var adService: AdService

    var body: some View {
        #if canImport(GoogleMobileAds)
        if adService.isInitialized && adService.canRequestAds {
            AdMobBannerRepresentable(adUnitID: AdService.bannerAdUnitID)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
        }
        #else
        EmptyView()
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerRepresentable: UIViewRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // ユニットIDが変わらない限り再ロード不要
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        private let logger = Logger(subsystem: "com.naritamasayuki.sleepapneacheck", category: "AdBanner")

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // ネットワーク切断や広告在庫なし時もアプリをクラッシュさせない
            logger.warning("AdMob banner load failed: \(error.localizedDescription)")
        }
    }
}
#endif
