import SwiftUI

struct AppCard<Content: View>: View {
    let content: Content
    var isHovered: Bool = false
    var padding: CGFloat = 24
    var cornerRadius: CGFloat = 24
    
    init(isHovered: Bool = false, padding: CGFloat = 24, cornerRadius: CGFloat = 24, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.isHovered = isHovered
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(isHovered ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    }
}
