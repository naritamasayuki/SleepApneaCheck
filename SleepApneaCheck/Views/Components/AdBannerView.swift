import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

/// Pro 未加入ユーザー向けに画面下部へ表示するバナー広告ビュー
struct AdBannerView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService

    var body: some View {
        if subscriptionService.isPro {
            EmptyView()
        } else {
            #if canImport(GoogleMobileAds)
            AdMobBannerRepresentable(adUnitID: AdService.bannerAdUnitID)
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))
            #else
            EmptyView()
            #endif
        }
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
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            // ネットワーク切断や広告在庫なし時もアプリをクラッシュさせない
            print("AdMob banner load failed: \(error.localizedDescription)")
        }
    }
}
#endif
