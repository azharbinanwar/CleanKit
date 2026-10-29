import SwiftUI

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
            // 1. Invisible backdrop: no dimming, but a click outside still closes.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // 2. The Dialog Card
            VStack(spacing: 0) {
                header

                // Fit height to content, scrolling only when it exceeds the cap.
                // ViewThatFits picks the plain content when it fits; measuring it
                // inside a ScrollView instead read back 0 and collapsed the list.
                ViewThatFits(in: .vertical) {
                    content.padding(24)
                    ScrollView { content.padding(24) }
                }
                .frame(maxHeight: contentCap)

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
                Rectangle().fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
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
