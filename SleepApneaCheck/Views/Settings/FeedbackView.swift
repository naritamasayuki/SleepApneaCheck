import SwiftUI
import UIKit

/// ユーザーからの要望・バグレポートを受け付けるフォーム画面
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var category: FeedbackCategory = .featureRequest
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var includeDeviceInfo: Bool = true
    @State private var copiedNotice: Bool = false
    @State private var mailUnavailableAlert: Bool = false
    @FocusState private var isInputFocused: Bool

    private var canSubmit: Bool {
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var builtSubject: String {
        FeedbackBuilder.makeSubject(category: category, customSubject: subject)
    }

    private var builtBody: String {
        FeedbackBuilder.makeCurrentBody(
            category: category,
            message: message,
            includeDeviceInfo: includeDeviceInfo
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(String(localized: "feedback.intro"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(String(localized: "feedback.section.details")) {
                    Picker(String(localized: "feedback.category.label"), selection: $category) {
                        ForEach(FeedbackCategory.allCases) { item in
                            Text(item.localizedTitle).tag(item)
                        }
                    }

                    TextField(String(localized: "feedback.subject.placeholder"), text: $subject)
                        .focused($isInputFocused)

                    ZStack(alignment: .topLeading) {
                        if message.isEmpty {
                            Text(String(localized: "feedback.message.placeholder"))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $message)
                            .frame(minHeight: 130)
                            .focused($isInputFocused)
                    }
                }

                Section {
                    Toggle(String(localized: "feedback.include_device_info"), isOn: $includeDeviceInfo)
                } footer: {
                    Text(String(localized: "feedback.device_info.footer"))
                }

                Section(String(localized: "feedback.section.send")) {
                    Button {
                        sendViaMail()
                    } label: {
                        Label(String(localized: "feedback.button.send_email"), systemImage: "envelope.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Button {
                        sendViaGitHub()
                    } label: {
                        Label(String(localized: "feedback.button.send_github"), systemImage: "ladybug.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canSubmit)

                    Button {
                        UIPasteboard.general.string = "\(builtSubject)\n\n\(builtBody)"
                        copiedNotice = true
                    } label: {
                        Label(
                            copiedNotice
                                ? String(localized: "feedback.button.copied")
                                : String(localized: "feedback.button.copy"),
                            systemImage: copiedNotice ? "checkmark.circle.fill" : "doc.on.doc"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle(String(localized: "feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.close")) {
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(String(localized: "common.done")) {
                        isInputFocused = false
                    }
                }
            }
            .alert(String(localized: "common.error"), isPresented: $mailUnavailableAlert) {
                Button(String(localized: "common.ok"), role: .cancel) {}
            } message: {
                Text(String(localized: "feedback.mail_unavailable"))
            }
        }
    }

    private func sendViaMail() {
        guard let url = FeedbackBuilder.makeMailtoURL(subject: builtSubject, body: builtBody) else {
            mailUnavailableAlert = true
            return
        }
        openURL(url) { accepted in
            if !accepted {
                mailUnavailableAlert = true
            }
        }
    }

    private func sendViaGitHub() {
        guard let url = FeedbackBuilder.makeGitHubIssueURL(
            category: category,
            subject: builtSubject,
            body: builtBody
        ) else { return }
        openURL(url)
    }
}
