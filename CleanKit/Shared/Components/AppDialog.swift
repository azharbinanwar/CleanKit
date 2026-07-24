import SwiftUI

private struct DialogContentHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct AppDialog<Content: View, Actions: View>: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let tint: Color
    let content: Content
    let actions: Actions
    let onDismiss: () -> Void
    var width: CGFloat = 520
    var maxHeight: CGFloat = 600

    @State private var contentHeight: CGFloat = 0

    /// Max height the scrollable content area may take (reserves room for the
    /// header and footer). Below this, the dialog just fits its content.
    private var contentCap: CGFloat { maxHeight - 180 }

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        tint: Color = .accentColor,
        width: CGFloat = 520,
        maxHeight: CGFloat = 600,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.width = width
        self.maxHeight = maxHeight
        self.onDismiss = onDismiss
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        ZStack {
            // 1. Transparent Backdrop (Click to close)
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // 2. The Dialog Card
            VStack(spacing: 0) {
                header

                // Fit height to content, scrolling only when it exceeds the cap.
                ScrollView {
                    content
                        .padding(24)
                        .background(GeometryReader { g in
                            Color.clear.preference(key: DialogContentHeight.self, value: g.size.height)
                        })
                }
                .frame(height: min(contentHeight, contentCap))
                .scrollDisabled(contentHeight <= contentCap) // no scrollbar when it fits
                .onPreferenceChange(DialogContentHeight.self) { contentHeight = $0 }

                VStack(spacing: 0) {
                    Divider().opacity(0.05)
                    HStack(spacing: 16) {
                        actions
                    }
                    .padding(24)
                }
            }
            .frame(width: width)
            .background(
                // Same frosted material + accent glow as the main app background.
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Circle()
                        .fill(tint.opacity(0.20))
                        .frame(width: 300, height: 300)
                        .blur(radius: 110)
                        .offset(x: -140, y: -170)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .onExitCommand { onDismiss() } // ESC key support
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(tint.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(tint)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 20, weight: .bold))
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}
