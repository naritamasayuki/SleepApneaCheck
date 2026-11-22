import Combine
import Foundation
import os
import StoreKit

/// StoreKit 2 を用いたサブスクリプション（収益化）管理サービス
@MainActor
final class SubscriptionService: ObservableObject {
    static let monthlyProductID = "com.sleepapneacheck.pro.monthly"
    static let yearlyProductID = "com.sleepapneacheck.pro.yearly"

    /// 無料プランの1回あたり最大録音秒数（5分 = 300秒）
    static let freeMaxRecordingSeconds: TimeInterval = 300
    /// 無料プランで閲覧可能な直近履歴件数
    static let freeHistoryLimit = 5

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private var transactionListener: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.sleepapneacheck.app", category: "SubscriptionService")

    init() {
        transactionListener = listenForTransactions()
        Task {
            await refreshStatus()
            await loadProducts()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    /// 商品情報を App Store / StoreKit から読み込む
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let storeProducts = try await Product.products(for: [
                Self.monthlyProductID,
                Self.yearlyProductID
            ])
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            logger.error("StoreKit商品取得失敗: \(error.localizedDescription)")
        }
    }

    /// 現在の購入ステータスを更新する
    func refreshStatus() async {
        var hasProEntitlement = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.monthlyProductID ||
                    transaction.productID == Self.yearlyProductID {
                    hasProEntitlement = true
                }
            }
        }
        isPro = hasProEntitlement
    }

    /// 商品を購入する
    func purchase(_ product: Product) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await refreshStatus()
                } else {
                    errorMessage = String(localized: "error.store.verification_failed")
                }
            case .userCancelled:
                break
            case .pending:
                errorMessage = String(localized: "store.purchase.pending")
            @unknown default:
                break
            }
        } catch {
            logger.error("購入処理失敗: \(error.localizedDescription)")
            errorMessage = String(localized: "error.store.purchase_failed")
        }
    }

    /// 購入を復元する
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await refreshStatus()
        } catch {
            logger.error("購入復元失敗: \(error.localizedDescription)")
            errorMessage = String(localized: "error.store.restore_failed")
        }
    }

    #if DEBUG
    /// 開発・動作確認用のProステータス切り替え
    func toggleDebugPro() {
        isPro.toggle()
    }
    #endif

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self?.refreshStatus()
                }
            }
        }
    }
}
