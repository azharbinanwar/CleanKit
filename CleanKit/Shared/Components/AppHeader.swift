import SwiftUI

struct AppHeader<Content: View>: View {
    let title: String?
    let subtitle: String?
    let trailingContent: Content?
    var isPlain: Bool = false

    init(title: String? = nil, subtitle: String? = nil, isPlain: Bool = false, @ViewBuilder trailingContent: () -> Content? = { nil }) {
        self.title = title
        self.subtitle = subtitle
        self.isPlain = isPlain
        self.trailingContent = trailingContent()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                if let title = title {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                }
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            if let trailingContent = trailingContent {
                trailingContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            if !isPlain {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
        .cornerRadius(isPlain ? 0 : 10)
        .overlay(
            Group {
                if !isPlain {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                }
            }
        )
    }
}

extension AppHeader where Content == EmptyView {
    init(title: String? = nil, subtitle: String? = nil, isPlain: Bool = false) {
        self.title = title
        self.subtitle = subtitle
        self.isPlain = isPlain
        self.trailingContent = nil
    }
}
