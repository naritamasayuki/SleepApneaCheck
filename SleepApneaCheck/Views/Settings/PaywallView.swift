import StoreKit
import SwiftUI

/// サブスクリプション（Proプラン）紹介・購入画面
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @State private var legalDocument: LegalDocumentType?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.yellow)
                        .padding(.top, 12)

                    Text(String(localized: "paywall.title"))
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    Text(String(localized: "paywall.subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    // Pro特典リスト
                    VStack(alignment: .leading, spacing: 14) {
                        featureRow(
                            icon: "infinity",
                            title: String(localized: "paywall.feature.unlimited_recording")
                        )
                        featureRow(
                            icon: "clock.arrow.circlepath",
                            title: String(localized: "paywall.feature.unlimited_history")
                        )
                        featureRow(
                            icon: "waveform.path.ecg",
                            title: String(localized: "paywall.feature.detailed_timeline")
                        )
                        featureRow(
                            icon: "doc.text.fill",
                            title: String(localized: "paywall.feature.doctor_report")
                        )
                        featureRow(
                            icon: "nosign",
                            title: String(localized: "paywall.feature.ad_free")
                        )
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    if subscriptionService.isPro {
                        Label(String(localized: "paywall.already_pro"), systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .padding()
                    } else if subscriptionService.products.isEmpty {
                        // StoreKit未接続環境向けのプレースホルダー表示
                        VStack(spacing: 12) {
                            Text(String(localized: "paywall.store_unavailable"))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        VStack(spacing: 12) {
                            ForEach(subscriptionService.products) { product in
                                Button {
                                    Task {
                                        await subscriptionService.purchase(product)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(product.displayName)
                                                .font(.headline)
                                            Text(product.description)
                                                .font(.caption)
                                                .opacity(0.85)
                                        }
                                        Spacer()
                                        Text(product.displayPrice)
                                            .font(.headline.bold())
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(subscriptionService.isLoading)
                            }
                        }
                    }

                    Button {
                        Task {
                            await subscriptionService.restorePurchases()
                        }
                    } label: {
                        Text(String(localized: "paywall.restore"))
                            .font(.subheadline)
                    }
                    .disabled(subscriptionService.isLoading)

                    if let errorMessage = subscriptionService.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    // サブスクリプション自動更新・法的文書リンク（App Store 審査準拠）
                    VStack(spacing: 8) {
                        Text(String(localized: "paywall.subscription_disclosure"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        HStack(spacing: 16) {
                            Button(String(localized: "legal.privacy_policy.title")) {
                                legalDocument = .privacyPolicy
                            }
                            Button(String(localized: "legal.terms.title")) {
                                legalDocument = .termsOfUse
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
            .sheet(item: $legalDocument) { doc in
                LegalDocumentView(documentType: doc)
            }
        }
    }

    private func featureRow(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
        }
    }
}
