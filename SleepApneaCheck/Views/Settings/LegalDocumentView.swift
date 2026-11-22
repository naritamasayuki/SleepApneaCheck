import SwiftUI

/// アプリ内で表示する法的文書種別
enum LegalDocumentType: String, Identifiable {
    case privacyPolicy
    case termsOfUse

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "legal.privacy_policy.title")
        case .termsOfUse:
            return String(localized: "legal.terms.title")
        }
    }

    var localizedBody: String {
        switch self {
        case .privacyPolicy:
            return String(localized: "legal.privacy_policy.body")
        case .termsOfUse:
            return String(localized: "legal.terms.body")
        }
    }
}

/// プライバシーポリシー・利用規約のアプリ内閲覧ビュー
struct LegalDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    let documentType: LegalDocumentType

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(documentType.localizedBody)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle(documentType.localizedTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}
