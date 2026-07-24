import SwiftUI

struct ToolHeaderView<Content: View>: View {
    let title: String
    let subtitle: String
    let actions: Content?

    init(title: String, subtitle: String, @ViewBuilder actions: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if let actions = actions {
                actions
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
}

extension ToolHeaderView where Content == EmptyView {
    init(title: String, subtitle: String) {
        self.title = title
        self.subtitle = subtitle
        self.actions = nil
    }
}
