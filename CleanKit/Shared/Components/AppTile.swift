import SwiftUI

struct AppTile<Content: View>: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil
    var isSelected: Bool = false
    var isEnabled: Bool = true
    var showChevron: Bool = false
    let action: () -> Void
    var trailingContent: Content?

    init(
        title: String,
        icon: String? = nil,
        subtitle: String? = nil,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        showChevron: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder trailingContent: () -> Content? = { nil }
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.showChevron = showChevron
        self.action = action
        self.trailingContent = trailingContent()
    }
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { if isEnabled { action() } }) {
            HStack(spacing: 12) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: isSelected ? .medium : .light))
                        .foregroundColor(isSelected ? .accentColor : .primary.opacity(0.8))
                        .frame(width: 24)
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    if !title.isEmpty {
                        Text(title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .primary : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                    }
                    
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                
                Spacer()
                
                if let trailingContent = trailingContent {
                    trailingContent
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.1) : isHovered && isEnabled ? Color.primary.opacity(0.03) : Color.white.opacity(0.0001))
            .cornerRadius(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

extension AppTile where Content == EmptyView {
    init(
        title: String,
        icon: String? = nil,
        subtitle: String? = nil,
        isSelected: Bool = false,
        isEnabled: Bool = true,
        showChevron: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.showChevron = showChevron
        self.action = action
        self.trailingContent = nil
    }
}
