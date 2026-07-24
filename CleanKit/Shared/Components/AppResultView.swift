import SwiftUI

struct AppResultView<Actions: View>: View {
    let title: String
    let subtitle: String
    let icon: String
    let stats: [(label: String, value: String, icon: String)]
    let actions: Actions
    
    @State private var isVisible = false
    
    init(
        title: String,
        subtitle: String,
        icon: String = "checkmark.seal.fill",
        stats: [(label: String, value: String, icon: String)] = [],
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.stats = stats
        self.actions = actions()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 40) {
                // 1. Animated Hero Icon
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 120, height: 120)
                    Image(systemName: icon)
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                }
                .scaleEffect(isVisible ? 1.0 : 0.6)
                .opacity(isVisible ? 1.0 : 0)
                
                // 2. Title & Message
                VStack(spacing: 12) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                    
                    Text(subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }
                .offset(y: isVisible ? 0 : 20)
                .opacity(isVisible ? 1.0 : 0)
                
                // 3. Stat Grid
                if !stats.isEmpty {
                    HStack(spacing: 20) {
                        ForEach(stats, id: \.label) { stat in
                            ResultStatCard(label: stat.label, value: stat.value, icon: stat.icon)
                        }
                    }
                    .scaleEffect(isVisible ? 1.0 : 0.9)
                    .opacity(isVisible ? 1.0 : 0)
                }
                
                // 4. Actions
                HStack(spacing: 16) {
                    actions
                }
                .opacity(isVisible ? 1.0 : 0)
            }
            .padding(60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(
            ZStack {
                // 1. Exact Material from AppCard
                Rectangle().fill(.ultraThinMaterial)
                
                // 2. Ambient Pink Glow to match App theme
                Circle()
                    .fill(Color.accentColor.opacity(0.03))
                    .blur(radius: 80)
                    .offset(x: -200, y: -200)
            }
        )
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
    }
}

private struct ResultStatCard: View {
    let label: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(24)
        .frame(minWidth: 180, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}
