import SwiftUI

/// 睡眠時の対策グッズや状況（飲酒・横向き枕など）を1タップで記録するタグピッカー
struct SleepCareTagPicker: View {
    @Binding var selectedTags: [SleepCareTag]

    private let columns = [
        GridItem(.adaptive(minimum: 130), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "tags.picker.title"))
                .font(.subheadline.bold())

            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
                ForEach(SleepCareTag.allCases) { tag in
                    let isSelected = selectedTags.contains(tag)
                    Button {
                        toggle(tag)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: tag.symbolName)
                                .font(.caption)
                            Text(tag.localizedTitle)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isSelected ? Color.blue : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func toggle(_ tag: SleepCareTag) {
        if let idx = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: idx)
        } else {
            selectedTags.append(tag)
        }
    }
}
