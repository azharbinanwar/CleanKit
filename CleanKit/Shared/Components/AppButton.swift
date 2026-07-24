import SwiftUI

enum AppButtonStyle {
    case primary
    case secondary
    case glass
    case plain
    case destructive
}

struct AppButton: View {
    let title: String
    var icon: String? = nil
    var style: AppButtonStyle = .glass
    var isEnabled: Bool = true
    var isLoading: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: { if isEnabled && !isLoading { action() } }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .bold))
                }
                
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 13, weight: .bold)) // Unified with footer size
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(backgroundView)
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(isHovered && isEnabled ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1.0 : 0.5)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            Color.accentColor
        case .destructive:
            Color.red
        case .secondary:
            Color.primary.opacity(0.05)
        case .glass:
            Color.clear.background(.ultraThinMaterial)
        case .plain:
            Color.clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary, .glass, .plain:
            return isHovered && isEnabled ? .accentColor : .primary.opacity(0.8)
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary, .destructive:
            return .clear
        case .secondary, .glass, .plain:
            return isHovered && isEnabled ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.05)
        }
    }
}
